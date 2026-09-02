
output "api_url" {
  description = "URL pública da HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
}
