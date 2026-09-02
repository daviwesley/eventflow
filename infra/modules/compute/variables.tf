
variable "project_name" {
  description = "Nome base dos recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente dos recursos."
  type        = string
}

variable "application_path" {
  description = "Caminho da aplicação Python a ser empacotada."
  type        = string
}

variable "build_in_docker" {
  description = "Se o empacotamento deve ocorrer em ambiente Docker compatível com Lambda."
  type        = bool
  default     = true
}

variable "docker_file" {
  description = "Dockerfile usado pelo build do pacote Lambda."
  type        = string
}

variable "artifacts_dir" {
  description = "Diretório local dos artefatos gerados pelo módulo Lambda."
  type        = string
}

variable "lambda_roles" {
  description = "ARN das roles IAM por função lógica."
  type        = map(string)
}

variable "queue_arns" {
  description = "ARNs das filas SQS por consumidor."
  type        = map(string)
}

variable "table_name" {
  description = "Nome da tabela DynamoDB."
  type        = string
}

variable "topic_arn" {
  description = "ARN do tópico SNS de eventos."
  type        = string
}

variable "log_retention_days" {
  description = "Dias de retenção dos logs das Lambdas."
  type        = number
  default     = 7
}
