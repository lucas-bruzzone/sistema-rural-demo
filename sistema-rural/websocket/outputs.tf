# ===================================
# WEBSOCKET API OUTPUTS
# ===================================

output "websocket_api_id" {
  description = "ID da API WebSocket"
  value       = aws_apigatewayv2_api.websocket.id
}

output "websocket_api_endpoint" {
  description = "Endpoint WebSocket"
  value       = aws_apigatewayv2_api.websocket.api_endpoint
}

output "websocket_stage_url" {
  description = "URL do stage WebSocket"
  value       = "${aws_apigatewayv2_api.websocket.api_endpoint}/${var.environment}"
}

output "websocket_api_arn" {
  description = "ARN da API WebSocket"
  value       = aws_apigatewayv2_api.websocket.arn
}

output "websocket_execution_arn" {
  description = "ARN de execução da API"
  value       = aws_apigatewayv2_api.websocket.execution_arn
}

# ===================================
# SUMMARY OUTPUT
# ===================================

output "websocket_summary" {
  description = "Resumo do módulo WebSocket"
  value = {
    api_id       = aws_apigatewayv2_api.websocket.id
    endpoint     = aws_apigatewayv2_api.websocket.api_endpoint
    stage_url    = "${aws_apigatewayv2_api.websocket.api_endpoint}/${var.environment}"
    environment  = var.environment
    routes       = ["$connect", "$disconnect", "subscribe", "unsubscribe"]
  }
}