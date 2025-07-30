# 🌾 Sistema Rural - Mapeamento de Propriedades

Sistema completo de mapeamento de propriedades rurais com análise geoespacial, desenvolvido com arquitetura serverless na AWS.

## 🚀 Demonstração

- **Frontend**: Hospedado via S3 + CloudFront
- **API**: AWS Lambda + API Gateway
- **Autenticação**: AWS Cognito
- **Notificações**: WebSocket em tempo real

## ✨ Funcionalidades

### 🗺️ Mapeamento Interativo
- Interface de mapeamento com Leaflet.js
- Desenho de propriedades com polígonos
- Visualização em múltiplas camadas (satélite, terreno)
- Cálculos automáticos de área e perímetro

### 📊 Análise Geoespacial
- Análise de elevação (SRTM)
- Índice de vegetação (NDVI)
- Cálculo de declividade
- Análise climática
- Distância de corpos d'água

### 📄 Relatórios
- Geração de relatórios PDF com ReportLab
- Exportação de dados de propriedades
- Métricas e estatísticas consolidadas

### 📁 Importação de Dados
- Upload de propriedades via CSV
- Validação automática dos dados
- Preview antes da importação

### 🔔 Notificações em Tempo Real
- WebSocket para atualizações instantâneas
- Notificações de análises concluídas
- Status de processamento em tempo real

## 🏗️ Arquitetura

### Componentes Principais

```
Frontend (S3 + CloudFront)
    ↓
API Gateway (REST)
    ↓
Lambda Functions
    ↓
DynamoDB + EventBridge + SQS
    ↓
WebSocket API
```

### Módulos do Sistema

1. **Infrastructure** - Base de dados e autenticação
2. **Lambda Authorizer** - Validação JWT para WebSocket
3. **Lambda CRUD** - Operações de propriedades + relatórios PDF
4. **Infrastructure Analysis** - EventBridge, SQS, S3 para análises
5. **Lambda Analysis** - Processamento geoespacial
6. **API Gateway** - REST API com autenticação Cognito
7. **Lambda WebSocket Handler** - Gerenciamento de conexões
8. **WebSocket Infrastructure** - API WebSocket
9. **Lambda Events Handler** - Processamento de eventos
10. **Frontend Infrastructure** - Hospedagem S3 + CloudFront

## 💻 Stack Tecnológico

### Frontend
- **Linguagens**: HTML5, CSS3, JavaScript ES6+
- **Mapas**: Leaflet.js, Turf.js para cálculos geométricos
- **UI**: CSS Grid/Flexbox, design responsivo
- **Auth**: AWS Cognito SDK

### Backend
- **Runtime**: Python 3.11
- **Compute**: AWS Lambda (serverless)
- **Database**: DynamoDB
- **Storage**: S3 para cache geoespacial
- **Auth**: AWS Cognito User Pools
- **Events**: EventBridge + SQS
- **APIs**: API Gateway REST + WebSocket

### DevOps
- **IaC**: Terraform
- **CI/CD**: GitHub Actions
- **Monitoramento**: CloudWatch
- **Distribuição**: CloudFront CDN

## 🚀 Deploy

### Pré-requisitos
- AWS CLI configurado
- Terraform >= 1.0
- Python 3.11+
- Credenciais AWS com permissões adequadas

### Deploy Automático via GitHub Actions

1. **Fork do repositório**
2. **Configurar Secrets**:
   ```
   AWS_ROLE_ARN: arn:aws:iam::ACCOUNT:role/GitHubActionsRole
   ```
3. **Push para main** - Deploy automático

### Deploy Manual

```bash
# 1. Configurar AWS
aws configure

# 2. Deploy sequencial dos módulos
cd sistema-rural/1.infrastructure
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../2.lambda-authorizer/terraform
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../3.lambda-crud/terraform
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../4.infrastructure-analysis
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../5.lambda-analysis/terraform
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../6.api-gateway
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../7.lambda-handle-websocket/terraform
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../8.websocket-infrastructure
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../9.lambda-handle-events/terraform
terraform init && terraform apply -var-file="tfvars/devops.tfvars"

cd ../10.frontend-infrastructure
terraform init && terraform apply -var-file="tfvars/devops.tfvars"
```

### Desenvolvimento Local

```bash
# Servir frontend localmente
cd frontend
python -m http.server 3000

# Abrir http://localhost:3000
```

## 📁 Estrutura do Projeto

```
sistema-rural/
├── 1.infrastructure/              # DynamoDB + Cognito
├── 2.lambda-authorizer/           # JWT validation
├── 3.lambda-crud/                 # CRUD + PDF reports
├── 4.infrastructure-analysis/     # EventBridge + SQS
├── 5.lambda-analysis/             # Geospatial analysis
├── 6.api-gateway/                 # REST API
├── 7.lambda-handle-websocket/     # WebSocket handler
├── 8.websocket-infrastructure/    # WebSocket API
├── 9.lambda-handle-events/        # Event processing
├── 10.frontend-infrastructure/    # S3 + CloudFront
├── frontend/src/                  # Frontend code
│   ├── index.html                 # Landing page
│   ├── dashboard.html             # Dashboard
│   ├── mapeamento.html            # Mapping interface
│   ├── css/styles.css             # Styles
│   └── js/                        # JavaScript modules
└── .github/workflows/             # CI/CD
```

## 🔧 Configuração

### Variáveis de Ambiente

Configurar em `tfvars/devops.tfvars`:

```hcl
aws_region   = "us-east-1"
project_name = "sistema-rural"
environment  = "devops"
domain_name  = ""  # Opcional: domínio customizado
```

### Configuração Cognito

O sistema gera automaticamente:
- User Pool para autenticação
- App Client para frontend
- Domínio hospedado para OAuth

## 📊 Recursos da API

### Endpoints Principais

```
GET  /properties              # Listar propriedades
POST /properties              # Criar propriedade
PUT  /properties/{id}         # Atualizar propriedade
DELETE /properties/{id}       # Deletar propriedade
POST /properties/import       # Importar CSV
POST /properties/report       # Gerar relatório PDF
GET  /properties/{id}/analysis # Buscar análise
```

### WebSocket

```
wss://API_ID.execute-api.region.amazonaws.com/stage?token=JWT_TOKEN

Actions:
- subscribe: Inscrever em tópicos
- unsubscribe: Desinscrever de tópicos
```

## 🔒 Segurança

- **Autenticação**: AWS Cognito com JWT
- **Autorização**: IAM roles com least privilege
- **CORS**: Configurado para domínios específicos
- **Validação**: Input validation em todas as APIs
- **Logs**: CloudWatch para auditoria

## 📈 Monitoramento

- **Logs**: CloudWatch Logs para todas as Lambdas
- **Métricas**: CloudWatch Metrics automáticas
- **Tracing**: X-Ray habilitado na API Gateway
- **Alertas**: CloudWatch Alarms para erros

## 🧪 Testes

### Teste Manual

1. Acesse a URL do frontend
2. Crie uma conta ou faça login
3. Navegue para "Mapeamento"
4. Desenhe uma propriedade
5. Verifique análise geoespacial
6. Gere relatório PDF

### Estrutura de Testes
- Validação de input nas APIs
- Testes de integração via GitHub Actions
- Validação de terraform plan/apply

## 🤝 Contribuição

1. Fork do projeto
2. Crie uma branch: `git checkout -b feature/nova-funcionalidade`
3. Commit: `git commit -am 'Adiciona nova funcionalidade'`
4. Push: `git push origin feature/nova-funcionalidade`
5. Pull Request

## 🐛 Solução de Problemas

### Problemas Comuns

**Erro de CORS**
- Verificar configuração CORS na API Gateway
- Confirmar domínio no Cognito

**Token inválido**
- Verificar expiração do JWT
- Refreshar token automaticamente

**Deploy falha**
- Verificar permissões IAM
- Confirmar ordem de deploy dos módulos

**Frontend não carrega**
- Verificar invalidação do CloudFront
- Confirmar arquivo config.js gerado

### Logs Úteis

```bash
# API Gateway
aws logs tail /aws/apigateway/sistema-rural-api --follow

# Lambda Functions
aws logs tail /aws/lambda/sistema-rural-properties-devops --follow

# WebSocket
aws logs tail /aws/apigateway/sistema-rural-websocket-api --follow
```

## 👨‍💻 Desenvolvedor

**Lucas Ricardo Duarte Bruzzone**
- 📧 lucas.rbruzzone@gmail.com
- 💼 [LinkedIn](https://www.linkedin.com/in/lucas-bruzzone/)
- 🎓 Mestre em Ciências da Computação (UFSCar)
- ☁️ AWS Certified AI Practitioner + Cloud Practitioner
- 👨‍🏫 Professor de Sistemas da Informação na Libertas Faculdades Integradas

---

## 🎯 Próximas Funcionalidades

- [ ] Análise de imagens de satélite com ML
- [ ] Integração com dados meteorológicos
- [ ] Dashboard de analytics avançado
- [ ] API mobile para campo
- [ ] Integração com drones para mapeamento

---

**Sistema Rural** - Transformando a gestão de propriedades rurais através da tecnologia ☁️🌱