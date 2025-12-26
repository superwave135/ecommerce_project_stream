# Development Environment Configuration
# Terraform variables for development environment

# General
aws_region   = "ap-southeast-1"
project_name = "ecommerce-streaming"
environment  = "dev"

# Kinesis
kinesis_shard_count     = 1
kinesis_retention_hours = 24

# Lambda
lambda_runtime          = "python3.11"
data_generator_memory   = 256
data_generator_timeout  = 300
orchestrator_memory     = 128
orchestrator_timeout    = 60
events_per_invocation   = 100

# Glue
glue_version         = "4.0"
glue_worker_type     = "G.1X"
glue_number_of_workers = 2
glue_max_capacity    = 2.0
glue_timeout         = 60

# RDS
db_instance_class          = "db.t3.micro"
db_engine_version          = "15.15"
db_allocated_storage       = 20
db_name                    = "ecommerce_analytics"
db_username                = "admin"
# db_password              = "CHANGE_ME_IN_TERRAFORM_APPLY"  # Pass via CLI: -var="db_password=YourSecurePassword"
db_port                    = 5432
db_backup_retention_period = 1
db_skip_final_snapshot     = true

# VPC
vpc_cidr                = "10.0.0.0/16"
public_subnet_cidrs     = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs    = ["10.0.10.0/24", "10.0.11.0/24"]
database_subnet_cidrs   = ["10.0.20.0/24", "10.0.21.0/24"]
availability_zones      = ["ap-southeast-1a", "ap-southeast-1b"]

# S3
s3_lifecycle_enabled      = true
s3_glacier_transition_days = 90
s3_expiration_days        = 365

# EventBridge (Disabled by default for manual control)
enable_scheduled_start = false
enable_scheduled_stop  = false
job_start_schedule     = "cron(0 9 * * ? *)"   # 9 AM UTC
job_stop_schedule      = "cron(0 10 * * ? *)"  # 10 AM UTC

# CodeBuild
github_repo_url        = "https://github.com/superwave135/ecommerce_project_stream"
github_branch          = "main"
codebuild_compute_type = "BUILD_GENERAL1_SMALL"
codebuild_image        = "aws/codebuild/standard:7.0"

# CloudWatch
log_retention_days        = 7
enable_detailed_monitoring = false

# Additional Tags
additional_tags = {
  Owner       = "geekytan"
  CostCenter  = "Demo_Streaming"
  Terraform   = "true"
}
