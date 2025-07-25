output "s3_bucket_name" {
  description = "Nome do bucket S3"
  value       = aws_s3_bucket.frontend.id
}

output "s3_bucket_website_endpoint" {
  description = "Endpoint do website S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição CloudFront"
  value       = aws_cloudfront_distribution.frontend.id
}

output "cloudfront_domain_name" {
  description = "Domain name do CloudFront"
  value       = aws_cloudfront_distribution.frontend.domain_name
}

output "frontend_url" {
  description = "URL do frontend"
  value       = "https://${aws_cloudfront_distribution.frontend.domain_name}"
}

output "config_js_path" {
  description = "Caminho do arquivo config.js gerado"
  value       = local_file.config_js.filename
}

output "cloudfront_invalidation_trigger" {
  description = "Trigger da invalidação do CloudFront"
  value       = null_resource.cloudfront_invalidation.id
}

output "frontend_summary" {
  description = "Resumo completo do frontend"
  value = {
    bucket_name          = aws_s3_bucket.frontend.id
    cloudfront_id        = aws_cloudfront_distribution.frontend.id
    cloudfront_domain    = aws_cloudfront_distribution.frontend.domain_name
    url                  = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    api_endpoint         = data.terraform_remote_state.api_gateway.outputs.api_gateway_url
    websocket_endpoint   = data.terraform_remote_state.websocket.outputs.websocket_stage_url
    cognito_domain       = "${data.terraform_remote_state.infrastructure.outputs.cognito_domain}.auth.${data.terraform_remote_state.infrastructure.outputs.cognito_region}.amazoncognito.com"
    environment          = var.environment
    invalidation_trigger = null_resource.cloudfront_invalidation.id
  }
}

# Debug: mostrar valores das variáveis
output "debug_config_values" {
  value = {
    api_gateway_url      = data.terraform_remote_state.api_gateway.outputs.api_gateway_url
    cognito_region       = data.terraform_remote_state.infrastructure.outputs.cognito_region
    cognito_user_pool_id = data.terraform_remote_state.infrastructure.outputs.cognito_user_pool_id
    cognito_client_id    = data.terraform_remote_state.infrastructure.outputs.cognito_client_id
    cognito_domain       = "${data.terraform_remote_state.infrastructure.outputs.cognito_domain}.auth.${data.terraform_remote_state.infrastructure.outputs.cognito_region}.amazoncognito.com"
    websocket_url        = data.terraform_remote_state.websocket.outputs.websocket_stage_url
    environment          = var.environment
  }
}