# ===================================
# PROJECT VARIABLES
# ===================================

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

variable "frontend_domain" {
  description = "Domínio do frontend para CORS"
  type        = string
  default     = "localhost:3000"
}

# ===================================
# TAGS PADRÃO
# ===================================

variable "default_tags" {
  description = "Tags padrão para recursos"
  type        = map(string)
  default = {
    Project     = "sistema-rural"
    Environment = "devops"
    Module      = "websocket"
    ManagedBy   = "terraform"
  }
}