"""
Serviço de notificações WebSocket - use em outras lambdas 
Exemplo: lambda-analysis pode usar para notificar análise completa
"""

import json
import boto3
import os
from datetime import datetime, timezone

def send_analysis_notification(property_id, user_id, analysis_data):
    """
    Enviar notificação de análise completa via WebSocket
    Chamada da lambda-analysis após processar análise
    """
    try:
        # Configurar cliente
        dynamodb = boto3.resource('dynamodb')
        connections_table = dynamodb.Table(os.environ['WEBSOCKET_TABLE'])
        
        # Buscar conexões do usuário subscritas no tópico 'analysis.completed'
        response = connections_table.scan(
            FilterExpression='userId = :userId',
            ExpressionAttributeValues={':userId': user_id}
        )
        
        target_connections = []
        for item in response['Items']:
            subscriptions = item.get('subscriptions', [])
            if 'analysis.completed' in subscriptions:
                target_connections.append(item['connectionId'])
        
        if not target_connections:
            print(f"Nenhuma conexão WebSocket ativa para usuário {user_id}")
            return
        
        # Preparar mensagem
        message = {
            'type': 'notification',
            'topic': 'analysis.completed',
            'data': {
                'propertyId': property_id,
                'analysis': analysis_data,
                'timestamp': datetime.now(timezone.utc).isoformat()
            }
        }
        
        # Enviar para conexões ativas
        apigateway = boto3.client('apigatewaymanagementapi', 
                                 endpoint_url=f"https://{os.environ['API_GATEWAY_ENDPOINT']}")
        
        sent_count = 0
        for connection_id in target_connections:
            try:
                apigateway.post_to_connection(
                    ConnectionId=connection_id,
                    Data=json.dumps(message)
                )
                sent_count += 1
                print(f"Notificação enviada para {connection_id}")
            except apigateway.exceptions.GoneException:
                # Conexão morta, remover
                connections_table.delete_item(Key={'connectionId': connection_id})
                print(f"Conexão morta removida: {connection_id}")
            except Exception as e:
                print(f"Erro ao enviar para {connection_id}: {str(e)}")
        
        print(f"Notificação enviada para {sent_count} conexões")
        
    except Exception as e:
        print(f"Erro no serviço de notificação: {str(e)}")

def send_property_update_notification(property_id, user_id, update_type, data):
    """
    Notificar atualização de propriedade (CRUD)
    """
    message = {
        'type': 'notification', 
        'topic': 'property.updated',
        'data': {
            'propertyId': property_id,
            'updateType': update_type,
            'data': data,
            'timestamp': datetime.now(timezone.utc).isoformat()
        }
    }
    
    broadcast_to_user_topic(user_id, 'property.updated', message)

def broadcast_to_user_topic(user_id, topic, message):
    """
    Broadcast genérico para um usuário em um tópico específico
    """
    try:
        dynamodb = boto3.resource('dynamodb')
        connections_table = dynamodb.Table(os.environ['WEBSOCKET_TABLE'])
        
        # Buscar conexões do usuário com o tópico
        response = connections_table.scan(
            FilterExpression='userId = :userId',
            ExpressionAttributeValues={':userId': user_id}
        )
        
        apigateway = boto3.client('apigatewaymanagementapi', 
                                 endpoint_url=f"https://{os.environ['API_GATEWAY_ENDPOINT']}")
        
        for item in response['Items']:
            subscriptions = item.get('subscriptions', [])
            if topic in subscriptions:
                try:
                    apigateway.post_to_connection(
                        ConnectionId=item['connectionId'],
                        Data=json.dumps(message)
                    )
                except Exception as e:
                    print(f"Erro ao enviar: {str(e)}")
                    
    except Exception as e:
        print(f"Erro no broadcast: {str(e)}")

# ===================================
# EXEMPLO DE USO NAS OUTRAS LAMBDAS
# ===================================

"""
# Na lambda-analysis/lambda_function.py, após completar análise:

from notification_service import send_analysis_notification

# ... código de análise ...

# Notificar via WebSocket
send_analysis_notification(
    property_id=property_id,
    user_id=user_id,
    analysis_data={
        'area': calculated_area,
        'perimeter': calculated_perimeter,
        'status': 'completed'
    }
)

# Na lambda-crud/lambda_function.py, após criar/atualizar propriedade:

from notification_service import send_property_update_notification

send_property_update_notification(
    property_id=property_id,
    user_id=user_id,
    update_type='created',
    data=property_data
)
"""