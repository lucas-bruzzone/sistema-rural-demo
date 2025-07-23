#!/usr/bin/env python3

import os
import sys
from pathlib import Path

def create_file(path, content=""):
    """Cria arquivo com conteúdo"""
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f"✅ {path}")

def create_monorepo_structure():
    """Cria estrutura completa do mono-repo"""
    
    base_dir = "sistema-rural"
    
    # Estrutura de diretórios
    directories = [
        "docs",
        "frontend/css",
        "frontend/js",
        "infrastructure/tfvars",
        "api-gateway/tfvars",
        "lambda-crud/src/lambda-layer",
        "lambda-crud/terraform/tfvars",
        "lambda-analysis/infrastructure/tfvars",
        "lambda-analysis/lambda/src/lambda-layer",
        "lambda-analysis/lambda/terraform/tfvars",
        "websocket/api/terraform/tfvars",
        "websocket/lambda-handler/src/lambda-layer",
        "websocket/lambda-handler/terraform/tfvars",
        "websocket/lambda-authorizer/src/lambda-layer",
        "websocket/lambda-authorizer/terraform/tfvars",
        "websocket/lambda-notifications/src/lambda-layer",
        "websocket/lambda-notifications/terraform/tfvars",
        "scripts"
    ]
    
    # Criar diretórios
    for directory in directories:
        Path(f"{base_dir}/{directory}").mkdir(parents=True, exist_ok=True)
    
    # =================== ROOT FILES ===================
    create_file(f"{base_dir}/README.md", """# 🌾 Sistema Rural - Mapeamento de Propriedades

Sistema completo de mapeamento de propriedades rurais com análise geoespacial.

## 🚀 Deploy Rápido

```bash
# 1. Configurar credenciais AWS
aws configure

# 2. Configurar variáveis
cp infrastructure/tfvars/devops.tfvars.example infrastructure/tfvars/devops.tfvars
# Editar com suas credenciais Google OAuth

# 3. Deploy completo
./deploy.sh devops us-east-1

# 4. Servir frontend
cd frontend && python -m http.server 3000
```

## 📁 Estrutura

- `infrastructure/` - DynamoDB, Cognito
- `api-gateway/` - REST API 
- `lambda-crud/` - CRUD propriedades
- `lambda-analysis/` - Análise geoespacial
- `websocket/` - Notificações tempo real
- `frontend/` - Interface web

Ver `docs/ARCHITECTURE.md` para detalhes.
""")

    create_file(f"{base_dir}/.gitignore", """# Terraform
**/.terraform/
**/.terraform.lock.hcl
**/terraform.tfstate
**/terraform.tfstate.backup
**/terraform.tfplan

# AWS
.aws/
*.pem

# Python
__pycache__/
*.pyc
*.pyo
*.egg-info/
venv/
.env

# Node
node_modules/
npm-debug.log*

# IDEs
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log

# Secrets
**/secret*
**/tfvars/devops.tfvars
!**/tfvars/devops.tfvars.example
""")

    create_file(f"{base_dir}/deploy.sh", """#!/bin/bash

set -e

echo "🚀 Deploy Sistema Rural Completo"
echo "================================"

ENVIRONMENT=${1:-devops}
AWS_REGION=${2:-us-east-1}

echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"

deploy_module() {
    local path=$1
    local name=$2
    
    echo ""
    echo "📦 Deploying $name..."
    cd $path
    terraform init -upgrade
    terraform plan -var-file="tfvars/$ENVIRONMENT.tfvars"
    terraform apply -var-file="tfvars/$ENVIRONMENT.tfvars" -auto-approve
    cd - > /dev/null
}

# Deploy sequencial
echo "🏗️ Iniciando deploy..."

deploy_module "infrastructure" "Infrastructure Base"
deploy_module "lambda-crud/terraform" "Lambda CRUD"
deploy_module "api-gateway" "API Gateway"
deploy_module "lambda-analysis/infrastructure" "Analysis Infrastructure"
deploy_module "lambda-analysis/lambda/terraform" "Analysis Lambda"
deploy_module "websocket/lambda-authorizer/terraform" "WebSocket Authorizer"
deploy_module "websocket/lambda-handler/terraform" "WebSocket Handler"
deploy_module "websocket/lambda-notifications/terraform" "WebSocket Notifications"
deploy_module "websocket/api/terraform" "WebSocket API"

echo ""
echo "✅ Deploy concluído!"
echo "🌐 Frontend: cd frontend && python -m http.server 3000"
""")

    create_file(f"{base_dir}/destroy.sh", """#!/bin/bash

set -e

echo "🗑️ Destroy Sistema Rural"
echo "========================"

ENVIRONMENT=${1:-devops}

destroy_module() {
    local path=$1
    local name=$2
    
    echo ""
    echo "🗑️ Destroying $name..."
    cd $path
    terraform destroy -var-file="tfvars/$ENVIRONMENT.tfvars" -auto-approve || true
    cd - > /dev/null
}

# Destroy em ordem reversa
destroy_module "websocket/api/terraform" "WebSocket API"
destroy_module "websocket/lambda-notifications/terraform" "WebSocket Notifications"
destroy_module "websocket/lambda-handler/terraform" "WebSocket Handler"
destroy_module "websocket/lambda-authorizer/terraform" "WebSocket Authorizer"
destroy_module "lambda-analysis/lambda/terraform" "Analysis Lambda"
destroy_module "lambda-analysis/infrastructure" "Analysis Infrastructure"
destroy_module "api-gateway" "API Gateway"
destroy_module "lambda-crud/terraform" "Lambda CRUD"
destroy_module "infrastructure" "Infrastructure Base"

echo "✅ Destroy concluído!"
""")

    # =================== INFRASTRUCTURE ===================
    create_file(f"{base_dir}/infrastructure/versions.tf", """terraform {
  backend "s3" {
    bucket         = "sistema-rural-terraform-state"
    key            = "infrastructure/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "sistema-rural-terraform-lock"
    encrypt        = true
  }

  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Environment = var.environment
      Project     = var.project_name
      ManagedBy   = "terraform"
      Repository  = "sistema-rural-monorepo"
    }
  }
}
""")

    create_file(f"{base_dir}/infrastructure/variables.tf", """variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "devops"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "sistema-rural"
}

variable "google_client_id" {
  description = "Google OAuth Client ID"
  type        = string
  sensitive   = true
}

variable "google_client_secret" {
  description = "Google OAuth Client Secret"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Custom domain name (optional)"
  type        = string
  default     = ""
}
""")

    create_file(f"{base_dir}/infrastructure/tfvars/devops.tfvars.example", """aws_region   = "us-east-1"
environment  = "devops"
project_name = "sistema-rural"

# Configure suas credenciais Google OAuth
google_client_id     = "your-google-client-id"
google_client_secret = "your-google-client-secret"

# Opcional: dominio customizado
domain_name = ""
""")

    # =================== SCRIPTS ===================
    create_file(f"{base_dir}/scripts/test-websocket.py", """#!/usr/bin/env python3

import boto3
import json
import websocket
import threading
import time

WEBSOCKET_URL = "wss://your-api-id.execute-api.us-east-1.amazonaws.com/devops"
COGNITO_CLIENT_ID = "your-client-id"
USERNAME = "your-email@example.com"
PASSWORD = "your-password"

def get_token():
    client = boto3.client('cognito-idp', region_name='us-east-1')
    response = client.initiate_auth(
        ClientId=COGNITO_CLIENT_ID,
        AuthFlow='USER_PASSWORD_AUTH',
        AuthParameters={'USERNAME': USERNAME, 'PASSWORD': PASSWORD}
    )
    return response['AuthenticationResult']['AccessToken']

def test_websocket():
    token = get_token()
    url = f"{WEBSOCKET_URL}?token={token}"
    
    def on_message(ws, message):
        print(f"📨 {json.loads(message)}")
    
    def on_open(ws):
        print("✅ Conectado")
        ws.send(json.dumps({"action": "subscribe", "topic": "test"}))
    
    ws = websocket.WebSocketApp(url, on_open=on_open, on_message=on_message)
    ws.run_forever()

if __name__ == "__main__":
    test_websocket()
""")

    # Tornar scripts executáveis
    os.chmod(f"{base_dir}/deploy.sh", 0o755)
    os.chmod(f"{base_dir}/destroy.sh", 0o755)
    os.chmod(f"{base_dir}/scripts/test-websocket.py", 0o755)

    print(f"\n🎉 Estrutura criada em: {base_dir}/")
    print("\n📋 Próximos passos:")
    print("1. cd sistema-rural")
    print("2. Configurar infrastructure/tfvars/devops.tfvars")
    print("3. ./deploy.sh")

if __name__ == "__main__":
    create_monorepo_structure()