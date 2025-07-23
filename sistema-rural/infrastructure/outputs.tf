# ===================================
# DYNAMODB OUTPUTS
# ===================================

output "properties_table_name" {
  description = "Nome da tabela de propriedades"
  value       = aws_dynamodb_table.properties.name
}

output "properties_table_arn" {
  description = "ARN da tabela de propriedades"
  value       = aws_dynamodb_table.properties.arn
}

output "property_analysis_table_name" {
  description = "Nome da tabela de análises"
  value       = aws_dynamodb_table.property_analysis.name
}

output "property_analysis_table_arn" {
  description = "ARN da tabela de análises"
  value       = aws_dynamodb_table.property_analysis.arn
}

output "websocket_connections_table_name" {
  description = "Nome da tabela de conexões WebSocket"
  value       = aws_dynamodb_table.websocket_connections.name
}

output "websocket_connections_table_arn" {
  description = "ARN da tabela de conexões WebSocket"
  value       = aws_dynamodb_table.websocket_connections.arn
}

# ===================================
# COGNITO OUTPUTS
# ===================================

output "cognito_user_pool_id" {
  description = "ID do User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN do User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_client_id" {
  description = "ID do App Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_domain" {
  description = "Domínio do Cognito"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_region" {
  description = "Região do Cognito"
  value       = var.aws_region
}

# ===================================
# INFRASTRUCTURE SUMMARY
# ===================================

output "infrastructure_summary" {
  description = "Resumo da infraestrutura base"
  value = {
    project_name = var.project_name
    environment  = var.environment
    region       = var.aws_region
    tables = {
      properties = aws_dynamodb_table.properties.name
      analysis   = aws_dynamodb_table.property_analysis.name
      websocket  = aws_dynamodb_table.websocket_connections.name
    }
    cognito = {
      user_pool_id = aws_cognito_user_pool.main.id
      client_id    = aws_cognito_user_pool_client.main.id
      domain       = aws_cognito_user_pool_domain.main.domain
    }
  }
}