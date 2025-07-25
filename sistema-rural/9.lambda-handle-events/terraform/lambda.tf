module "lambda_events_handler" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.7"

  function_name = "${var.project_name}-events-handler-${var.environment}"
  source_path   = "../src"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 60
  memory_size   = 256

  create_role = false
  lambda_role = aws_iam_role.lambda_events_role.arn

  environment_variables = {
    WEBSOCKET_TABLE        = data.terraform_remote_state.infrastructure.outputs.websocket_connections_table_name
    WEBSOCKET_API_ENDPOINT = data.terraform_remote_state.websocket_infra.outputs.websocket_stage_url
    ENVIRONMENT            = var.environment
  }

  tags = var.default_tags
}

# ===================================
# EVENTBRIDGE RULES PARA LAMBDA
# ===================================

# Rule para capturar eventos de propriedades
resource "aws_cloudwatch_event_rule" "property_events_to_lambda" {
  name           = "${var.project_name}-property-events-to-lambda"
  description    = "Send property events to Lambda for WebSocket notifications"
  event_bus_name = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name

  event_pattern = jsonencode({
    source      = ["property.service"]
    detail-type = ["Property Created", "Property Updated", "Property Deleted"]
  })

  tags = var.default_tags
}

# Rule para capturar eventos de análise
resource "aws_cloudwatch_event_rule" "analysis_events_to_lambda" {
  name           = "${var.project_name}-analysis-events-to-lambda"
  description    = "Send analysis events to Lambda for WebSocket notifications"
  event_bus_name = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name

  event_pattern = jsonencode({
    source      = ["geospatial.analysis"]
    detail-type = ["Analysis Completed", "Analysis Started", "Analysis Failed"]
  })

  tags = var.default_tags
}

# ===================================
# TARGETS PARA AS RULES
# ===================================

# Target para eventos de propriedades
resource "aws_cloudwatch_event_target" "property_events_lambda_target" {
  rule           = aws_cloudwatch_event_rule.property_events_to_lambda.name
  event_bus_name = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name
  target_id      = "PropertyEventsLambdaTarget"
  arn            = module.lambda_events_handler.lambda_function_arn
}

# Target para eventos de análise
resource "aws_cloudwatch_event_target" "analysis_events_lambda_target" {
  rule           = aws_cloudwatch_event_rule.analysis_events_to_lambda.name
  event_bus_name = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name
  target_id      = "AnalysisEventsLambdaTarget"
  arn            = module.lambda_events_handler.lambda_function_arn
}

# ===================================
# LAMBDA PERMISSIONS
# ===================================

# Permission para EventBridge invocar a Lambda - Property Events
resource "aws_lambda_permission" "allow_eventbridge_property" {
  statement_id  = "AllowExecutionFromEventBridgeProperty"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_events_handler.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.property_events_to_lambda.arn
}

# Permission para EventBridge invocar a Lambda - Analysis Events
resource "aws_lambda_permission" "allow_eventbridge_analysis" {
  statement_id  = "AllowExecutionFromEventBridgeAnalysis"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda_events_handler.lambda_function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.analysis_events_to_lambda.arn
}