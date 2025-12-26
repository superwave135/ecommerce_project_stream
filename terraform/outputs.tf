# Terraform Outputs
# Export important resource information

# ============================================
# VPC Outputs
# ============================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = aws_subnet.private[*].id
}

output "database_subnet_ids" {
  description = "Database subnet IDs"
  value       = aws_subnet.database[*].id
}

# ============================================
# Kinesis Outputs
# ============================================

output "clicks_stream_name" {
  description = "Clicks Kinesis stream name"
  value       = aws_kinesis_stream.clicks.name
}

output "clicks_stream_arn" {
  description = "Clicks Kinesis stream ARN"
  value       = aws_kinesis_stream.clicks.arn
}

output "checkouts_stream_name" {
  description = "Checkouts Kinesis stream name"
  value       = aws_kinesis_stream.checkouts.name
}

output "checkouts_stream_arn" {
  description = "Checkouts Kinesis stream ARN"
  value       = aws_kinesis_stream.checkouts.arn
}

# ============================================
# Lambda Outputs
# ============================================

output "data_generator_function_name" {
  description = "Data generator Lambda function name"
  value       = aws_lambda_function.data_generator.function_name
}

output "data_generator_function_arn" {
  description = "Data generator Lambda function ARN"
  value       = aws_lambda_function.data_generator.arn
}

output "orchestrator_function_name" {
  description = "Orchestrator Lambda function name"
  value       = aws_lambda_function.orchestrator.function_name
}

output "orchestrator_function_arn" {
  description = "Orchestrator Lambda function ARN"
  value       = aws_lambda_function.orchestrator.arn
}

# ============================================
# Glue Outputs
# ============================================

output "glue_job_name" {
  description = "Glue streaming job name"
  value       = aws_glue_job.stream_processor.name
}

output "glue_job_arn" {
  description = "Glue streaming job ARN"
  value       = aws_glue_job.stream_processor.arn
}

# ============================================
# RDS Outputs
# ============================================

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgres.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.postgres.db_name
}

output "rds_username" {
  description = "RDS master username"
  value       = aws_db_instance.postgres.username
  sensitive   = true
}

# ============================================
# S3 Outputs
# ============================================

output "scripts_bucket_name" {
  description = "S3 bucket for scripts"
  value       = aws_s3_bucket.scripts.id
}

output "scripts_bucket_arn" {
  description = "S3 bucket ARN for scripts"
  value       = aws_s3_bucket.scripts.arn
}

# ============================================
# CodeBuild Outputs
# ============================================

output "codebuild_data_generator_name" {
  description = "CodeBuild project name for data generator"
  value       = aws_codebuild_project.data_generator.name
}

output "codebuild_orchestrator_name" {
  description = "CodeBuild project name for orchestrator"
  value       = aws_codebuild_project.orchestrator.name
}

output "codebuild_glue_name" {
  description = "CodeBuild project name for Glue job"
  value       = aws_codebuild_project.glue_job.name
}

# ============================================
# CloudWatch Outputs
# ============================================

output "log_group_data_generator" {
  description = "CloudWatch log group for data generator"
  value       = aws_cloudwatch_log_group.data_generator.name
}

output "log_group_orchestrator" {
  description = "CloudWatch log group for orchestrator"
  value       = aws_cloudwatch_log_group.orchestrator.name
}

output "log_group_glue" {
  description = "CloudWatch log group for Glue job"
  value       = aws_cloudwatch_log_group.glue.name
}

# ============================================
# Connection Information
# ============================================

output "connection_info" {
  description = "Connection information for all services"
  value = {
    kinesis_clicks_stream    = aws_kinesis_stream.clicks.name
    kinesis_checkouts_stream = aws_kinesis_stream.checkouts.name
    rds_endpoint             = aws_db_instance.postgres.endpoint
    rds_database             = aws_db_instance.postgres.db_name
    glue_job_name            = aws_glue_job.stream_processor.name
    scripts_bucket           = aws_s3_bucket.scripts.id
  }
}

# ============================================
# Cost Estimation (Hourly Session)
# ============================================

output "estimated_hourly_cost" {
  description = "Estimated cost per 1-hour session"
  value = {
    kinesis_on_demand = "$0.015 - $0.04 (per million PUT payload units)"
    glue_streaming    = "$0.44 (2 DPU × $0.44/DPU-hour × 1 hour)"
    lambda            = "$0.001 - $0.003 (based on invocations)"
    rds               = "$0.016 (db.t3.micro hourly rate)"
    total_estimate    = "$0.50 - $0.60 per 1-hour session"
    note              = "Use terraform destroy after each session to minimize costs"
  }
}
