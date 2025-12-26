# Lambda Functions Configuration

# ============================================
# Lambda Function - Data Generator
# ============================================

# Create deployment package from source
data "archive_file" "data_generator" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/data_generator"
  output_path = "${path.module}/../lambda/data_generator/lambda_function.zip"
  excludes    = ["lambda_function.zip", "buildspec.yml", "__pycache__"]
}

resource "aws_lambda_function" "data_generator" {
  filename      = data.archive_file.data_generator.output_path
  function_name = "${local.resource_prefix}-data-generator"
  role          = aws_iam_role.data_generator.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.data_generator_timeout
  memory_size   = var.data_generator_memory
  source_code_hash = data.archive_file.data_generator.output_base64sha256
  
  environment {
    variables = {
      CLICKS_STREAM_NAME       = aws_kinesis_stream.clicks.name
      CHECKOUTS_STREAM_NAME    = aws_kinesis_stream.checkouts.name
      EVENTS_PER_INVOCATION    = var.events_per_invocation
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.data_generator_basic,
    aws_cloudwatch_log_group.data_generator
  ]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-data-generator"
    }
  )
}

# ============================================
# Lambda Function - Orchestrator
# ============================================

# Create deployment package from source
data "archive_file" "orchestrator" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/orchestrator"
  output_path = "${path.module}/../lambda/orchestrator/lambda_function.zip"
  excludes    = ["lambda_function.zip", "buildspec.yml", "__pycache__"]
}

resource "aws_lambda_function" "orchestrator" {
  filename      = data.archive_file.orchestrator.output_path
  function_name = "${local.resource_prefix}-orchestrator"
  role          = aws_iam_role.orchestrator.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_runtime
  timeout       = var.orchestrator_timeout
  memory_size   = var.orchestrator_memory
  source_code_hash = data.archive_file.orchestrator.output_base64sha256
  
  environment {
    variables = {
      GLUE_JOB_NAME    = aws_glue_job.stream_processor.name
      GLUE_JOB_TIMEOUT = var.glue_timeout
    }
  }
  
  depends_on = [
    aws_iam_role_policy_attachment.orchestrator_basic,
    aws_cloudwatch_log_group.orchestrator
  ]
  
  tags = merge(
    local.common_tags,
    {
      Name = "${local.resource_prefix}-orchestrator"
    }
  )
}

# ============================================
# Lambda Permissions for EventBridge
# ============================================

resource "aws_lambda_permission" "allow_eventbridge_data_generator" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_generator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.data_generation.arn
}

resource "aws_lambda_permission" "allow_eventbridge_orchestrator_start" {
  count         = var.enable_scheduled_start ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeStart"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.job_start[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_orchestrator_stop" {
  count         = var.enable_scheduled_stop ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridgeStop"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.job_stop[0].arn
}
