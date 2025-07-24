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

output "frontend_summary" {
  description = "Resumo do módulo frontend"
  value = {
    bucket_name        = aws_s3_bucket.frontend.id
    cloudfront_id      = aws_cloudfront_distribution.frontend.id
    url                = "https://${aws_cloudfront_distribution.frontend.domain_name}"
    api_endpoint       = data.terraform_remote_state.api_gateway.outputs.api_gateway_url
    websocket_endpoint = data.terraform_remote_state.websocket.outputs.websocket_stage_url
  }
}