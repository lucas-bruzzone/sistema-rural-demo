variable "project_name" {
  description = "Nome do projeto"
  type        = string
  default     = "sistema-rural"
}

variable "environment" {
  description = "Ambiente (dev, prod)"
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
    Module      = "frontend-infrastructure"
    ManagedBy   = "terraform"
  }
}