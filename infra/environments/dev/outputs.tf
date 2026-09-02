output "environment" {
  description = "Ambiente provisionado."
  value       = var.environment
}

output "api_url" {
  description = "URL pública da HTTP API."
  value       = module.api.api_url
}

output "table_name" {
  description = "Nome da tabela Single Table do DynamoDB."
  value       = module.data.table_name
}

output "queue_urls" {
  description = "URLs das filas de processamento."
  value       = module.messaging.queue_urls
}
