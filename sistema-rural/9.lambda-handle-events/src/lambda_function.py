import json
import boto3
import os
from datetime import datetime, timezone

# AWS clients
dynamodb = boto3.resource("dynamodb")
connections_table = dynamodb.Table(os.environ["WEBSOCKET_TABLE"])


def lambda_handler(event, context):
    """Handler para processar eventos e enviar notificações WebSocket"""
    
    try:
        # Determinar tipo de evento
        if "Records" in event:
            # Evento vindo do SQS/EventBridge
            for record in event["Records"]:
                if "eventSource" in record and record["eventSource"] == "aws:sqs":
                    handle_sqs_message(record)
                else:
                    handle_direct_event(record)
        else:
            # Chamada direta da função
            handle_direct_event(event)
            
        return {"statusCode": 200, "body": "Events processed"}
        
    except Exception as e:
        print(f"Erro no processamento de eventos: {str(e)}")
        return {"statusCode": 500, "body": str(e)}


def handle_sqs_message(record):
    """Processar mensagem do SQS"""
    body = json.loads(record["body"])
    
    # Se for mensagem do EventBridge
    if "detail" in body:
        event_detail = body["detail"]
        event_type = body.get("detail-type", "")
        
        if "Analysis Completed" in event_type:
            handle_analysis_completed(event_detail)
        elif "Property Created" in event_type:
            handle_property_created(event_detail)
        elif "Property Updated" in event_type:
            handle_property_updated(event_detail)


def handle_direct_event(event_data):
    """Processar evento direto"""
    event_type = event_data.get("eventType", "")
    
    if event_type == "analysis_completed":
        send_analysis_notification(
            event_data["propertyId"],
            event_data["userId"],
            event_data["analysisData"]
        )
    elif event_type == "property_notification":
        send_property_notification(
            event_data["userId"],
            event_data["topic"],
            event_data["message"]
        )


def handle_analysis_completed(event_detail):
    """Processar análise concluída"""
    property_id = event_detail.get("propertyId")
    
    if property_id:
        # Buscar usuário da propriedade (normalmente viria no evento)
        user_id = event_detail.get("userId", "unknown")
        
        send_analysis_notification(
            property_id,
            user_id,
            {
                "propertyId": property_id,
                "status": "completed",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        )


def handle_property_created(event_detail):
    """Processar propriedade criada"""
    send_property_notification(
        event_detail.get("userId"),
        "property.created",
        f"Nova propriedade criada: {event_detail.get('propertyName', 'Sem nome')}"
    )


def handle_property_updated(event_detail):
    """Processar propriedade atualizada"""
    send_property_notification(
        event_detail.get("userId"),
        "property.updated",
        f"Propriedade atualizada: {event_detail.get('propertyName', 'Sem nome')}"
    )


def send_analysis_notification(property_id, user_id, analysis_data):
    """Enviar notificação de análise completa"""
    message = {
        "type": "analysis_notification",
        "event": "completed",
        "propertyId": property_id,
        "message": f"Análise da propriedade {property_id} foi concluída!",
        "data": analysis_data,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    broadcast_to_user_topic(user_id, "analysis.completed", message)


def send_property_notification(user_id, topic, message_text):
    """Enviar notificação de propriedade"""
    message = {
        "type": "property_notification",
        "topic": topic,
        "message": message_text,
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
    
    broadcast_to_user_topic(user_id, topic, message)


def broadcast_to_user_topic(user_id, topic, message):
    """Broadcast para um usuário em um tópico específico"""
    try:
        # Buscar conexões do usuário
        response = connections_table.scan(
            FilterExpression="userId = :userId",
            ExpressionAttributeValues={":userId": user_id}
        )
        
        if not response.get("Items"):
            print(f"Nenhuma conexão WebSocket ativa para usuário {user_id}")
            return
        
        # Configurar API Gateway Management
        endpoint = os.environ.get("WEBSOCKET_API_ENDPOINT", "").replace("wss://", "https://")
        if not endpoint:
            print("WEBSOCKET_API_ENDPOINT não configurado")
            return
            
        apigateway = boto3.client("apigatewaymanagementapi", endpoint_url=endpoint)
        
        sent_count = 0
        for item in response["Items"]:
            subscriptions = item.get("subscriptions", [])
            
            # Verificar se está subscrito no tópico
            if topic in subscriptions:
                connection_id = item["connectionId"]
                
                try:
                    apigateway.post_to_connection(
                        ConnectionId=connection_id,
                        Data=json.dumps(message)
                    )
                    sent_count += 1
                    print(f"Notificação enviada para {connection_id}")
                    
                except apigateway.exceptions.GoneException:
                    # Conexão morta, remover
                    connections_table.delete_item(Key={"connectionId": connection_id})
                    print(f"Conexão morta removida: {connection_id}")
                    
                except Exception as e:
                    print(f"Erro ao enviar para {connection_id}: {str(e)}")
        
        print(f"Notificação '{topic}' enviada para {sent_count} conexões do usuário {user_id}")
        
    except Exception as e:
        print(f"Erro no broadcast: {str(e)}")