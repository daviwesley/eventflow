
variable "project_name" {
  description = "Nome base dos recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente dos recursos."
  type        = string
}

variable "dlq_arns" {
  description = "ARNs das DLQs por consumidor."
  type        = map(string)
}
