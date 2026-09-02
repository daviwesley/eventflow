
output "lambda_role_arns" {
  description = "ARNs das roles das Lambdas por função lógica."
  value       = { for name, role in aws_iam_role.lambda : name => role.arn }
}
