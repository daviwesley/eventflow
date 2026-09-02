
variable "project_name" {
  description = "Nome base dos recursos."
  type        = string
}

variable "environment" {
  description = "Ambiente dos recursos."
  type        = string
}

variable "lambda_function_name" {
  description = "Nome da Lambda integrada à API."
  type        = string
}

variable "lambda_function_arn" {
  description = "ARN da Lambda integrada à API."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "ARN de invocação da Lambda integrada à API."
  type        = string
}

variable "allow_origins" {
  description = "Origens permitidas pelo CORS."
  type        = list(string)
  default     = ["*"]
}
