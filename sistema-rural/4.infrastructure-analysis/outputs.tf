# ===================================
# S3 OUTPUTS
# ===================================

output "geospatial_cache_bucket_name" {
  description = "Nome do bucket S3 para cache geoespacial"
  value       = aws_s3_bucket.geospatial_cache.bucket
}

output "geospatial_cache_bucket_arn" {
  description = "ARN do bucket S3 para cache geoespacial"
  value       = aws_s3_bucket.geospatial_cache.arn
}

# ===================================
# EVENTBRIDGE OUTPUTS
# ===================================

output "property_analysis_bus_name" {
  description = "Nome do EventBridge custom bus"
  value       = aws_cloudwatch_event_bus.property_analysis.name
}

output "property_analysis_bus_arn" {
  description = "ARN do EventBridge custom bus"
  value       = aws_cloudwatch_event_bus.property_analysis.arn
}

output "property_created_rule_name" {
  description = "Nome da rule EventBridge para property created"
  value       = aws_cloudwatch_event_rule.property_created.name
}

output "property_created_rule_arn" {
  description = "ARN da rule EventBridge para property created"
  value       = aws_cloudwatch_event_rule.property_created.arn
}

# ===================================
# SQS OUTPUTS
# ===================================

output "property_analysis_delay_queue_name" {
  description = "Nome da SQS queue com delay"
  value       = aws_sqs_queue.property_analysis_delay.name
}

output "property_analysis_delay_queue_arn" {
  description = "ARN da SQS queue com delay"
  value       = aws_sqs_queue.property_analysis_delay.arn
}

output "property_analysis_delay_queue_url" {
  description = "URL da SQS queue com delay"
  value       = aws_sqs_queue.property_analysis_delay.url
}

output "property_analysis_dlq_name" {
  description = "Nome da dead letter queue"
  value       = aws_sqs_queue.property_analysis_dlq.name
}

output "property_analysis_dlq_arn" {
  description = "ARN da dead letter queue"
  value       = aws_sqs_queue.property_analysis_dlq.arn
}

# ===================================
# IAM OUTPUTS
# ===================================

output "eventbridge_role_arn" {
  description = "ARN da role do EventBridge"
  value       = aws_iam_role.eventbridge_role.arn
}

output "lambda_analysis_role_arn" {
  description = "ARN da role da Lambda de análise"
  value       = aws_iam_role.lambda_analysis_role.arn
}

output "lambda_analysis_role_name" {
  description = "Nome da role da Lambda de análise"
  value       = aws_iam_role.lambda_analysis_role.name
}

# ===================================
# INTEGRATION INFO
# ===================================

output "infrastructure_summary" {
  description = "Resumo da infraestrutura criada"
  value = {
    environment     = var.environment
    project_name    = var.project_name
    region          = var.aws_region
    s3_bucket       = aws_s3_bucket.geospatial_cache.bucket
    eventbridge_bus = aws_cloudwatch_event_bus.property_analysis.name
    sqs_queue       = aws_sqs_queue.property_analysis_delay.name
    delay_seconds   = 120
  }
}