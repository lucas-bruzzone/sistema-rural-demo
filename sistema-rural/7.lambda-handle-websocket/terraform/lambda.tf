module "lambda_websocket_handler" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.7"

  function_name = "${var.project_name}-websocket-handler-${var.environment}"
  source_path   = "../src"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256

  create_role = false
  lambda_role = aws_iam_role.lambda_websocket_role.arn

  environment_variables = {
    WEBSOCKET_TABLE      = data.terraform_remote_state.infrastructure.outputs.websocket_connections_table_name
    API_GATEWAY_ENDPOINT = "${var.project_name}-websocket-api.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    ENVIRONMENT          = var.environment
  }

  tags = var.default_tags
}