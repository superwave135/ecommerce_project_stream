# Terraform Variables
# Define all input variables for the infrastructure

# ============================================
# General Configuration
# ============================================

variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "ecommerce-streaming"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

# ============================================
# Kinesis Configuration
# ============================================

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis streams"
  type        = number
  default     = 1
}

variable "kinesis_retention_hours" {
  description = "Data retention period in hours"
  type        = number
  default     = 24
}

# ============================================
# Lambda Configuration
# ============================================

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.11"
}

variable "data_generator_memory" {
  description = "Memory allocation for data generator Lambda (MB)"
  type        = number
  default     = 256
}

variable "data_generator_timeout" {
  description = "Timeout for data generator Lambda (seconds)"
  type        = number
  default     = 300
}

variable "orchestrator_memory" {
  description = "Memory allocation for orchestrator Lambda (MB)"
  type        = number
  default     = 128
}

variable "orchestrator_timeout" {
  description = "Timeout for orchestrator Lambda (seconds)"
  type        = number
  default     = 60
}

variable "events_per_invocation" {
  description = "Number of events to generate per Lambda invocation"
  type        = number
  default     = 100
}

# ============================================
# Glue Configuration
# ============================================

variable "glue_version" {
  description = "AWS Glue version"
  type        = string
  default     = "4.0"
}

variable "glue_worker_type" {
  description = "Glue worker type (G.1X, G.2X)"
  type        = string
  default     = "G.1X"
}

variable "glue_number_of_workers" {
  description = "Number of Glue workers"
  type        = number
  default     = 2
}

variable "glue_max_capacity" {
  description = "Maximum DPU capacity for Glue job"
  type        = number
  default     = 2.0
}

variable "glue_timeout" {
  description = "Glue job timeout in minutes"
  type        = number
  default     = 60
}

# ============================================
# RDS Configuration
# ============================================

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.4"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS (GB)"
  type        = number
  default     = 20
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "ecommerce_analytics"
}

variable "db_username" {
  description = "Master username for RDS"
  type        = string
  default     = "admin"
  sensitive   = true
}

variable "db_password" {
  description = "Master password for RDS"
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 1
}

variable "db_skip_final_snapshot" {
  description = "Skip final snapshot when destroying"
  type        = bool
  default     = true
}

# ============================================
# VPC Configuration
# ============================================

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for database subnets"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["ap-southeast-1a", "ap-southeast-1b"]
}

# ============================================
# S3 Configuration
# ============================================

variable "s3_lifecycle_enabled" {
  description = "Enable S3 lifecycle policies"
  type        = bool
  default     = true
}

variable "s3_glacier_transition_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "s3_expiration_days" {
  description = "Days before object expiration"
  type        = number
  default     = 365
}

# ============================================
# EventBridge Configuration
# ============================================

variable "enable_scheduled_start" {
  description = "Enable automatic job start via EventBridge"
  type        = bool
  default     = false
}

variable "job_start_schedule" {
  description = "Cron expression for job start (UTC)"
  type        = string
  default     = "cron(0 9 * * ? *)"  # 9 AM UTC daily
}

variable "enable_scheduled_stop" {
  description = "Enable automatic job stop via EventBridge"
  type        = bool
  default     = false
}

variable "job_stop_schedule" {
  description = "Cron expression for job stop (UTC)"
  type        = string
  default     = "cron(0 10 * * ? *)"  # 10 AM UTC daily
}

# ============================================
# CodeBuild Configuration
# ============================================

variable "github_repo_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "github_branch" {
  description = "GitHub branch to monitor"
  type        = string
  default     = "main"
}

variable "codebuild_compute_type" {
  description = "CodeBuild compute type"
  type        = string
  default     = "BUILD_GENERAL1_SMALL"
}

variable "codebuild_image" {
  description = "CodeBuild Docker image"
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

# ============================================
# CloudWatch Configuration
# ============================================

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed CloudWatch monitoring"
  type        = bool
  default     = false
}

# ============================================
# Tagging
# ============================================

variable "additional_tags" {
  description = "Additional tags for resources"
  type        = map(string)
  default     = {}
}
