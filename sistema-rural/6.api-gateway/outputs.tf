# ===================================
# API GATEWAY OUTPUTS
# ===================================

output "api_gateway_id" {
  description = "ID da API Gateway"
  value       = aws_api_gateway_rest_api.main.id
}

output "api_gateway_arn" {
  description = "ARN da API Gateway"
  value       = aws_api_gateway_rest_api.main.arn
}

output "api_gateway_url" {
  description = "URL base da API Gateway"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
}

output "api_gateway_stage_name" {
  description = "Nome do stage da API"
  value       = aws_api_gateway_stage.main.stage_name
}

output "api_gateway_execution_arn" {
  description = "ARN de execução da API Gateway"
  value       = aws_api_gateway_rest_api.main.execution_arn
}

output "api_gateway_invoke_url" {
  description = "URL de invocação da API Gateway"
  value       = aws_api_gateway_stage.main.invoke_url
}

output "api_summary" {
  description = "Resumo da API Gateway"
  value = {
    api_id      = aws_api_gateway_rest_api.main.id
    stage_name  = aws_api_gateway_stage.main.stage_name
    url         = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.aws_region}.amazonaws.com/${aws_api_gateway_stage.main.stage_name}"
    invoke_url  = aws_api_gateway_stage.main.invoke_url
    environment = var.environment
    region      = var.aws_region
  }
}