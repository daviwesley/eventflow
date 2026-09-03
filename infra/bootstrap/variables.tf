variable "aws_region" {
  description = "Região AWS onde o bucket de state será criado."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome curto do projeto usado no nome padrão do bucket."
  type        = string
  default     = "reservation-service"
}

variable "bucket_name" {
  description = "Nome globalmente único do bucket; vazio usa projeto + account ID."
  type        = string
  default     = ""
}
