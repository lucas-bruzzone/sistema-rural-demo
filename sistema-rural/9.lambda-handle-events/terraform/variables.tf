variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "sistema-rural"
}

variable "environment" {
  description = "Ambiente"
  type        = string
  default     = "devops"
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
  default     = "us-east-1"
}

variable "default_tags" {
  description = "Tags padrão"
  type        = map(string)
  default = {
    Project     = "sistema-rural"
    Environment = "devops"
    Module      = "lambda-handle-events"
    ManagedBy   = "terraform"
  }
}