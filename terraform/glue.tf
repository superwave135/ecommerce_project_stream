# AWS Glue Configuration

# ============================================
# Upload Glue Script to S3
# ============================================

resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue-jobs/stream_processor.py"
  source = "${path.module}/../glue/jobs/stream_processor.py"
  etag   = filemd5("${path.module}/../glue/jobs/stream_processor.py")
  
  tags = local.common_tags
}

# ============================================
# Security Group for Glue
# ============================================

resource "aws_security_group" "glue" {
  name        = "${local.resource_prefix}-glue-sg"
  description = "Security group for Glue streaming job"
  vpc_id      = aws_vpc.main.id
  
  # Self-referencing rule for Glue ENIs
  ingress {
    from_port = 0
    to_port   = 65535
    protocol  = "tcp"
    self      = true
    description = "Allow all traffic from same security group"
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-glue-sg"
    }
  )
}

# ============================================
# Glue Connection for RDS
# ============================================

resource "aws_glue_connection" "postgres" {
  name = "${local.resource_prefix}-postgres-connection"
  
  connection_properties = {
    JDBC_CONNECTION_URL = "jdbc:postgresql://${aws_db_instance.postgres.address}:${aws_db_instance.postgres.port}/${aws_db_instance.postgres.db_name}"
    USERNAME            = var.db_username
    PASSWORD            = var.db_password
  }
  
  physical_connection_requirements {
    availability_zone      = var.availability_zones[0]
    security_group_id_list = [aws_security_group.glue.id]
    subnet_id              = aws_subnet.private[0].id
  }
}

# Allow Glue job to connect to RDS
resource "aws_security_group_rule" "glue_to_rds" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.postgres.id
  source_security_group_id = aws_security_group.glue.id
  description              = "Allow Glue job to connect to PostgreSQL"
}

# ============================================
# Glue Streaming Job
# ============================================

resource "aws_glue_job" "stream_processor" {
  name     = "${local.resource_prefix}-stream-processor"
  role_arn = aws_iam_role.glue_job.arn
  
  # Glue version and settings
  glue_version = var.glue_version
  worker_type  = var.glue_worker_type
  number_of_workers = var.glue_number_of_workers
  
  # Streaming job configuration
  command {
    name            = "gluestreaming"
    script_location = "s3://${aws_s3_bucket.scripts.id}/glue-jobs/stream_processor.py"
    python_version  = "3"
  }
  
  # Default arguments
  default_arguments = {
    "--job-language"                     = "python"
    "--job-bookmark-option"              = "job-bookmark-disable"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--enable-spark-ui"                  = "true"
    "--spark-event-logs-path"            = "s3://${aws_s3_bucket.scripts.id}/spark-logs/"
    "--TempDir"                          = "s3://${aws_s3_bucket.scripts.id}/temp/"
    
    # Custom parameters
    "--CLICKS_STREAM_NAME"    = aws_kinesis_stream.clicks.name
    "--CHECKOUTS_STREAM_NAME" = aws_kinesis_stream.checkouts.name
    "--CHECKPOINT_LOCATION"   = "s3://${aws_s3_bucket.scripts.id}/checkpoints/"
    "--DATABASE_HOST"         = aws_db_instance.postgres.address
    "--DATABASE_NAME"         = aws_db_instance.postgres.db_name
    "--DATABASE_USER"         = var.db_username
    "--DATABASE_PASSWORD"     = var.db_password
    "--DATABASE_PORT"         = tostring(var.db_port)
    
    # Additional Spark configurations
    "--conf" = "spark.sql.streaming.schemaInference=true"
  }
  
  # Execution properties
  execution_property {
    max_concurrent_runs = 1
  }
  
  # Timeout
  timeout = var.glue_timeout
  
  # Connections
  connections = [aws_glue_connection.postgres.name]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-stream-processor"
    }
  )
  
  depends_on = [
    aws_s3_object.glue_jobs_folder,
    aws_s3_object.temp_folder,
    aws_s3_object.spark_logs_folder,
    aws_s3_object.checkpoints_folder,
    aws_s3_object.glue_script
  ]
}
