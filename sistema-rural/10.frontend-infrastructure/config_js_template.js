// Sistema Rural - Configuração dinâmica
// Este arquivo é gerado automaticamente pelo Terraform
window.SISTEMA_RURAL_CONFIG = {
    // API Gateway
    API_BASE_URL: '${api_gateway_url}',
    
    // AWS Cognito
    COGNITO: {
        region: '${cognito_region}',
        userPoolId: '${cognito_user_pool_id}',
        clientId: '${cognito_client_id}',
        domain: '${cognito_domain}'
    },
    
    // WebSocket
    WEBSOCKET_URL: '${websocket_url}',
    
    // Environment
    ENVIRONMENT: '${environment}',
    
    // Version
    VERSION: '1.2.1'
};