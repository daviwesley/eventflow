
variable "project_name" {
  description = "Nome base dos recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente dos recursos."
  type        = string
}

variable "table_arn" {
  description = "ARN da tabela DynamoDB."
  type        = string
}

variable "topic_arn" {
  description = "ARN do tópico SNS."
  type        = string
}

variable "consumer_queue_arns" {
  description = "ARNs das filas SQS por consumidor."
  type        = map(string)
}
