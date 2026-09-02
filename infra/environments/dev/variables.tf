variable "aws_region" {
  description = "Região AWS do ambiente."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome base dos recursos do projeto."
  type        = string
  default     = "reservation-service"
}

variable "environment" {
  description = "Nome do ambiente Terraform."
  type        = string
  default     = "dev"
}

