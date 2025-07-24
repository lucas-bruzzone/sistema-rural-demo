# ===================================
# WEBSOCKET API GATEWAY
# ===================================

resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project_name}-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  cors_configuration {
    allow_credentials = true
    allow_origins     = ["https://${var.frontend_domain}", "http://localhost:3000"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
  }

  tags = {
    Name = "${var.project_name}-websocket-api"
    Type = "websocket"
  }
}

# ===================================
# WEBSOCKET ROUTES
# ===================================

# $connect route  
resource "aws_apigatewayv2_route" "connect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_handler.id}"
  
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.websocket_auth.id
}

# $disconnect route
resource "aws_apigatewayv2_route" "disconnect" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_handler.id}"
}

# subscribe route
resource "aws_apigatewayv2_route" "subscribe" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "subscribe"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_handler.id}"
}

# unsubscribe route
resource "aws_apigatewayv2_route" "unsubscribe" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "unsubscribe"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_handler.id}"
}

# ===================================
# WEBSOCKET INTEGRATIONS (UMA LAMBDA PARA TUDO)
# ===================================

# Única integração para todas as rotas
resource "aws_apigatewayv2_integration" "websocket_handler" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
}

# ===================================
# ROUTE RESPONSES
# ===================================

resource "aws_apigatewayv2_route_response" "connect" {
  api_id             = aws_apigatewayv2_api.websocket.id
  route_id           = aws_apigatewayv2_route.connect.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route_response" "disconnect" {
  api_id             = aws_apigatewayv2_api.websocket.id
  route_id           = aws_apigatewayv2_route.disconnect.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route_response" "subscribe" {
  api_id             = aws_apigatewayv2_api.websocket.id
  route_id           = aws_apigatewayv2_route.subscribe.id
  route_response_key = "$default"
}

resource "aws_apigatewayv2_route_response" "unsubscribe" {
  api_id             = aws_apigatewayv2_api.websocket.id
  route_id           = aws_apigatewayv2_route.unsubscribe.id
  route_response_key = "$default"
}

# ===================================
# LAMBDA FUNCTION
# ===================================

# ZIP do código da lambda
data "archive_file" "websocket_handler" {
  type        = "zip"
  source_dir  = "${path.module}/lambda-websocket"
  output_path = "${path.module}/websocket-handler.zip"
}

# Lambda Function
resource "aws_lambda_function" "websocket_handler" {
  filename         = data.archive_file.websocket_handler.output_path
  function_name    = "${var.project_name}-websocket-handler"
  role            = aws_iam_role.websocket_lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 30

  source_code_hash = data.archive_file.websocket_handler.output_base64sha256

  environment {
    variables = {
      WEBSOCKET_TABLE      = data.terraform_remote_state.infrastructure.outputs.websocket_connections_table_name
      API_GATEWAY_ENDPOINT = "${aws_apigatewayv2_api.websocket.id}.execute-api.${var.aws_region}.amazonaws.com/${var.environment}"
    }
  }

  tags = var.default_tags
}

# CloudWatch Log Group para Lambda
resource "aws_cloudwatch_log_group" "websocket_lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.websocket_handler.function_name}"
  retention_in_days = 7
  tags             = var.default_tags
}

# ===================================
# IAM ROLE E POLICIES PARA LAMBDA  
# ===================================

resource "aws_iam_role" "websocket_lambda_role" {
  name = "${var.project_name}-websocket-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

# Policy básica para Lambda
resource "aws_iam_role_policy_attachment" "websocket_lambda_basic" {
  role       = aws_iam_role.websocket_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Policy customizada para DynamoDB e API Gateway
resource "aws_iam_role_policy" "websocket_lambda_custom" {
  name = "${var.project_name}-websocket-lambda-policy"
  role = aws_iam_role.websocket_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ]
        Resource = data.terraform_remote_state.infrastructure.outputs.websocket_connections_table_arn
      },
      {
        Effect = "Allow"
        Action = [
          "execute-api:ManageConnections"
        ]
        Resource = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
      }
    ]
  })
}

# ===================================
# DEPLOYMENT & STAGE
# ===================================

resource "aws_apigatewayv2_deployment" "websocket" {
  api_id = aws_apigatewayv2_api.websocket.id

  depends_on = [
    aws_apigatewayv2_route.connect,
    aws_apigatewayv2_route.disconnect,
    aws_apigatewayv2_route.subscribe,
    aws_apigatewayv2_route.unsubscribe,
    aws_apigatewayv2_integration.websocket_handler
# ===================================
# AUTHORIZER
# ===================================

resource "aws_apigatewayv2_authorizer" "websocket_auth" {
  api_id                            = aws_apigatewayv2_api.websocket.id
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = data.terraform_remote_state.lambda_authorizer.outputs.lambda_invoke_arn
  name                              = "${var.project_name}-websocket-authorizer"
  authorizer_result_ttl_in_seconds  = 300

  identity_sources = [
    "route.request.querystring.token"
  ]
}
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "websocket" {
  api_id        = aws_apigatewayv2_api.websocket.id
  deployment_id = aws_apigatewayv2_deployment.websocket.id
  name          = var.environment
  auto_deploy   = true

  default_route_settings {
    throttling_rate_limit    = 1000
    throttling_burst_limit   = 2000
    logging_level            = "INFO"
    data_trace_enabled       = true
    detailed_metrics_enabled = true
  }

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.websocket_api_logs.arn
    format = jsonencode({
      requestId        = "$context.requestId"
      connectionId     = "$context.connectionId"
      routeKey         = "$context.routeKey"
      eventType        = "$context.eventType"
      status           = "$context.status"
      error            = "$context.error.message"
      integrationError = "$context.integrationErrorMessage"
      requestTime      = "$context.requestTime"
      responseLength   = "$context.responseLength"
    })
  }

  tags = {
    Name = "${var.project_name}-websocket-stage"
  }
}

# ===================================
# CLOUDWATCH LOGS
# ===================================

resource "aws_cloudwatch_log_group" "websocket_api_logs" {
  name              = "/aws/apigateway/${var.project_name}-websocket-api"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-websocket-api-logs"
  }
}

# ===================================
# LAMBDA PERMISSIONS
# ===================================

# ===================================
# LAMBDA PERMISSIONS
# ===================================

# Permissão única para a lambda ser invocada pelo API Gateway
resource "aws_lambda_permission" "websocket_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

# Permissão para o authorizer
resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_authorizer.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.websocket_auth.id}"
}