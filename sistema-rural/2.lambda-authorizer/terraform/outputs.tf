output "lambda_function_name" {
  description = "Name of the authorizer Lambda function"
  value       = module.lambda_function.lambda_function_name
}

output "lambda_function_arn" {
  description = "ARN of the authorizer Lambda function"
  value       = module.lambda_function.lambda_function_arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the authorizer Lambda function"
  value       = module.lambda_function.lambda_function_invoke_arn
}

output "lambda_layer_arn" {
  description = "ARN of the authorizer Lambda layer"
  value       = module.lambda_layer.lambda_layer_arn
}