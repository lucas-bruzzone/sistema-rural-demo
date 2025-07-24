output "lambda_function_name" {
  description = "Nome da função Lambda"
  value       = module.lambda_websocket_handler.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN da função Lambda"
  value       = module.lambda_websocket_handler.lambda_function_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN da função Lambda"
  value       = module.lambda_websocket_handler.lambda_function_invoke_arn
}

output "lambda_role_arn" {
  description = "ARN da role da Lambda"
  value       = aws_iam_role.lambda_websocket_role.arn
}