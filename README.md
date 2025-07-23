# 🌾 Sistema Rural - Mapeamento de Propriedades

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
