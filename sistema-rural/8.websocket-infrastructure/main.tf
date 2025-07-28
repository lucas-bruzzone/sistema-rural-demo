# ===================================
# WEBSOCKET API GATEWAY
# ===================================

resource "aws_apigatewayv2_api" "websocket" {
  name                       = "${var.project_name}-websocket-api"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"

  tags = var.default_tags
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

# OPTIONS for CORS
resource "aws_apigatewayv2_route" "options" {
  api_id    = aws_apigatewayv2_api.websocket.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.websocket_handler.id}"
}

# ===================================
# WEBSOCKET INTEGRATIONS
# ===================================

resource "aws_apigatewayv2_integration" "websocket_handler" {
  api_id           = aws_apigatewayv2_api.websocket.id
  integration_type = "AWS_PROXY"
  integration_uri  = data.terraform_remote_state.lambda_websocket.outputs.lambda_invoke_arn
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
# AUTHORIZER
# ===================================

resource "aws_apigatewayv2_authorizer" "websocket_auth" {
  api_id          = aws_apigatewayv2_api.websocket.id
  authorizer_type = "REQUEST"
  authorizer_uri  = data.terraform_remote_state.lambda_authorizer.outputs.lambda_invoke_arn
  name            = "${var.project_name}-websocket-authorizer"

  identity_sources = [
    "route.request.querystring.token"
  ]
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
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_apigatewayv2_stage" "websocket" {
  api_id      = aws_apigatewayv2_api.websocket.id
  name        = var.environment
  auto_deploy = true

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

  tags = var.default_tags
}

# ===================================
# CLOUDWATCH LOGS
# ===================================

resource "aws_cloudwatch_log_group" "websocket_api_logs" {
  name              = "/aws/apigateway/${var.project_name}-websocket-api"
  retention_in_days = 7
  tags              = var.default_tags
}

# ===================================
# LAMBDA PERMISSIONS
# ===================================

resource "aws_lambda_permission" "websocket_handler" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_websocket.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/*/*"
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_authorizer.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.websocket.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.websocket_auth.id}"
}