# S3 Bucket Configuration

# ============================================
# S3 Bucket for Scripts and Data
# ============================================

resource "aws_s3_bucket" "scripts" {
  bucket = "${local.resource_prefix}-scripts-${local.account_id}"
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-scripts-bucket"
    }
  )
}

# Enable versioning
resource "aws_s3_bucket_versioning" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  
  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "scripts" {
  bucket = aws_s3_bucket.scripts.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy
resource "aws_s3_bucket_lifecycle_configuration" "scripts" {
  count  = var.s3_lifecycle_enabled ? 1 : 0
  bucket = aws_s3_bucket.scripts.id
  
  rule {
    id     = "archive-old-files"
    status = "Enabled"
    
    transition {
      days          = var.s3_glacier_transition_days
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.s3_expiration_days
    }
    
    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "GLACIER"
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }
  
  rule {
    id     = "cleanup-temp-files"
    status = "Enabled"
    
    filter {
      prefix = "temp/"
    }
    
    expiration {
      days = 7
    }
  }
  
  rule {
    id     = "cleanup-logs"
    status = "Enabled"
    
    filter {
      prefix = "spark-logs/"
    }
    
    expiration {
      days = 30
    }
  }
}

# ============================================
# S3 Bucket Folders (via objects)
# ============================================

resource "aws_s3_object" "glue_jobs_folder" {
  bucket = aws_s3_bucket.scripts.id
  key    = "glue-jobs/"
  
  tags = local.common_tags
}

resource "aws_s3_object" "temp_folder" {
  bucket = aws_s3_bucket.scripts.id
  key    = "temp/"
  
  tags = local.common_tags
}

resource "aws_s3_object" "spark_logs_folder" {
  bucket = aws_s3_bucket.scripts.id
  key    = "spark-logs/"
  
  tags = local.common_tags
}

resource "aws_s3_object" "checkpoints_folder" {
  bucket = aws_s3_bucket.scripts.id
  key    = "checkpoints/"
  
  tags = local.common_tags
}
