
output "api_function_name" {
  description = "Nome da Lambda HTTP."
  value       = module.lambda["api"].lambda_function_name
}

output "api_function_arn" {
  description = "ARN da Lambda HTTP."
  value       = module.lambda["api"].lambda_function_arn
}

output "api_invoke_arn" {
  description = "ARN de invocação da Lambda HTTP."
  value       = module.lambda["api"].lambda_function_invoke_arn
}
