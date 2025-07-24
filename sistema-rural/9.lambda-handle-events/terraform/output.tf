output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda_events_handler.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = module.lambda_events_handler.lambda_function_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN da função Lambda"
  value       = module.lambda_events_handler.lambda_function_invoke_arn
}
