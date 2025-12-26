# EventBridge Configuration
# Orchestrates data generation and job management

# ============================================
# EventBridge Rule - Data Generation (Every 5 minutes during active session)
# ============================================

resource "aws_cloudwatch_event_rule" "data_generation" {
  name                = "${local.resource_prefix}-data-generation"
  description         = "Trigger data generator Lambda every 5 minutes"
  schedule_expression = "rate(5 minutes)"
  state               = "DISABLED"  # Manually enable when needed
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "data_generation" {
  rule      = aws_cloudwatch_event_rule.data_generation.name
  target_id = "DataGeneratorLambda"
  arn       = aws_lambda_function.data_generator.arn
}

# ============================================
# EventBridge Rule - Job Start (Optional - Scheduled)
# ============================================

resource "aws_cloudwatch_event_rule" "job_start" {
  count               = var.enable_scheduled_start ? 1 : 0
  name                = "${local.resource_prefix}-job-start"
  description         = "Start Glue streaming job"
  schedule_expression = var.job_start_schedule
  state               = "ENABLED"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "job_start" {
  count     = var.enable_scheduled_start ? 1 : 0
  rule      = aws_cloudwatch_event_rule.job_start[0].name
  target_id = "OrchestratorLambdaStart"
  arn       = aws_lambda_function.orchestrator.arn
  
  input = jsonencode({
    action = "start"
  })
}

# ============================================
# EventBridge Rule - Job Stop (Optional - Scheduled)
# ============================================

resource "aws_cloudwatch_event_rule" "job_stop" {
  count               = var.enable_scheduled_stop ? 1 : 0
  name                = "${local.resource_prefix}-job-stop"
  description         = "Stop Glue streaming job"
  schedule_expression = var.job_stop_schedule
  state               = "ENABLED"
  
  tags = local.common_tags
}

resource "aws_cloudwatch_event_target" "job_stop" {
  count     = var.enable_scheduled_stop ? 1 : 0
  rule      = aws_cloudwatch_event_rule.job_stop[0].name
  target_id = "OrchestratorLambdaStop"
  arn       = aws_lambda_function.orchestrator.arn
  
  input = jsonencode({
    action = "stop"
  })
}
