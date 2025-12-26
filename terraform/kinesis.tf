# Kinesis Streams Configuration
# Creates Kinesis data streams for clicks and checkouts

# ============================================
# Kinesis Stream - Clicks
# ============================================

resource "aws_kinesis_stream" "clicks" {
  name = "${local.resource_prefix}-clicks"
  
  # Use on-demand mode for cost optimization (pay per use)
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
  
  retention_period = var.kinesis_retention_hours
  
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis.id
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.resource_prefix}-clicks-stream"
      StreamType  = "Clicks"
      DataType    = "ClickEvents"
    }
  )
}

# ============================================
# Kinesis Stream - Checkouts
# ============================================

resource "aws_kinesis_stream" "checkouts" {
  name = "${local.resource_prefix}-checkouts"
  
  # Use on-demand mode for cost optimization (pay per use)
  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }
  
  retention_period = var.kinesis_retention_hours
  
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis.id
  
  tags = merge(
    local.common_tags,
    {
      Name        = "${local.resource_prefix}-checkouts-stream"
      StreamType  = "Checkouts"
      DataType    = "CheckoutEvents"
    }
  )
}

# ============================================
# KMS Key for Kinesis Encryption
# ============================================

resource "aws_kms_key" "kinesis" {
  description             = "KMS key for Kinesis stream encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-kinesis-kms"
    }
  )
}

resource "aws_kms_alias" "kinesis" {
  name          = "alias/${local.resource_prefix}-kinesis"
  target_key_id = aws_kms_key.kinesis.key_id
}

# ============================================
# CloudWatch Alarms for Kinesis
# ============================================

# Alarm for high iterator age (data processing lag)
resource "aws_cloudwatch_metric_alarm" "clicks_iterator_age" {
  alarm_name          = "${local.resource_prefix}-clicks-high-iterator-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "60000"  # 1 minute
  alarm_description   = "Clicks stream iterator age is high (processing lag)"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StreamName = aws_kinesis_stream.clicks.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "checkouts_iterator_age" {
  alarm_name          = "${local.resource_prefix}-checkouts-high-iterator-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Maximum"
  threshold           = "60000"  # 1 minute
  alarm_description   = "Checkouts stream iterator age is high (processing lag)"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StreamName = aws_kinesis_stream.checkouts.name
  }
  
  tags = local.common_tags
}

# Alarm for throttled records
resource "aws_cloudwatch_metric_alarm" "clicks_throttled_records" {
  alarm_name          = "${local.resource_prefix}-clicks-throttled-records"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteProvisionedThroughputExceeded"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Clicks stream has throttled write records"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StreamName = aws_kinesis_stream.clicks.name
  }
  
  tags = local.common_tags
}

resource "aws_cloudwatch_metric_alarm" "checkouts_throttled_records" {
  alarm_name          = "${local.resource_prefix}-checkouts-throttled-records"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteProvisionedThroughputExceeded"
  namespace           = "AWS/Kinesis"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Checkouts stream has throttled write records"
  treat_missing_data  = "notBreaching"
  
  dimensions = {
    StreamName = aws_kinesis_stream.checkouts.name
  }
  
  tags = local.common_tags
}