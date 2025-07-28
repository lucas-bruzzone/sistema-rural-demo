// Sistema Rural - Configuração dinâmica
window.SISTEMA_RURAL_CONFIG = {
    // API Gateway
    API_BASE_URL: '${API_GATEWAY_URL}',
    
    // AWS Cognito
    COGNITO: {
        region: '${COGNITO_REGION}',
        userPoolId: '${COGNITO_USER_POOL_ID}',
        clientId: '${COGNITO_CLIENT_ID}',
        domain: '${COGNITO_DOMAIN}'
    },
    
    // WebSocket
    WEBSOCKET_URL: '${WEBSOCKET_URL}',
    
    // Environment
    ENVIRONMENT: '${ENVIRONMENT}',
    
    // Version
    VERSION: '1.2.1'
};