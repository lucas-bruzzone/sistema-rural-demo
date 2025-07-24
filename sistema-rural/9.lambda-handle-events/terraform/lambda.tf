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
    WEBSOCKET_API_ENDPOINT = data.terraform_remote_state.websocket_infra.outputs.websocket_api_endpoint
    ENVIRONMENT            = var.environment
  }

  tags = var.default_tags
}