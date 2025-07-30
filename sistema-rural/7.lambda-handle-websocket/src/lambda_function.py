import json
import boto3
import os
from datetime import datetime, timezone, timedelta
from boto3.dynamodb.conditions import Key

# AWS clients
dynamodb = boto3.resource("dynamodb")
connections_table = dynamodb.Table(os.environ["WEBSOCKET_TABLE"])


def lambda_handler(event, context):
    """Handler único para todas as rotas WebSocket"""

    route_key = event["requestContext"]["routeKey"]
    connection_id = event["requestContext"]["connectionId"]

    # Criar cliente API Gateway Management com endpoint correto
    domain_name = event["requestContext"]["domainName"]
    stage = event["requestContext"]["stage"]
    endpoint_url = f"https://{domain_name}/{stage}"

    apigateway = boto3.client("apigatewaymanagementapi", endpoint_url=endpoint_url)

    try:
        if route_key == "$connect":
            return handle_connect(event, connection_id)
        elif route_key == "$disconnect":
            return handle_disconnect(connection_id)
        elif route_key == "subscribe":
            return handle_subscribe(event, connection_id, apigateway)
        elif route_key == "unsubscribe":
            return handle_unsubscribe(event, connection_id, apigateway)
        else:
            return {"statusCode": 404, "body": "Route not found"}

    except Exception as e:
        print(f"Erro geral: {str(e)}")
        return {"statusCode": 500, "body": "Internal server error"}


def handle_connect(event, connection_id):
    """Processar conexão"""
    # Extrair userId do authorizer
    user_id = event["requestContext"]["authorizer"].get("userId")

    if not user_id:
        return {"statusCode": 401, "body": "Unauthorized"}

    # TTL para 24 horas
    ttl = int((datetime.now(timezone.utc) + timedelta(hours=24)).timestamp())

    # Salvar conexão
    connections_table.put_item(
        Item={
            "connectionId": connection_id,
            "userId": user_id,
            "connectedAt": datetime.now(timezone.utc).isoformat(),
            "ttl": ttl,
            "subscriptions": [],
        }
    )

    print(f"Conectado: {connection_id} - usuário {user_id}")
    return {"statusCode": 200}


def handle_disconnect(connection_id):
    """Processar desconexão"""
    connections_table.delete_item(Key={"connectionId": connection_id})
    print(f"Desconectado: {connection_id}")
    return {"statusCode": 200}


def handle_subscribe(event, connection_id, apigateway):
    """Processar subscrição"""
    body = json.loads(event.get("body", "{}"))
    topic = body.get("topic")

    if not topic:
        send_message(
            apigateway,
            connection_id,
            {"type": "error", "message": "Topic é obrigatório"},
        )
        return {"statusCode": 400}

    # Buscar conexão
    response = connections_table.get_item(Key={"connectionId": connection_id})
    if "Item" not in response:
        return {"statusCode": 404}

    # Atualizar subscrições
    item = response["Item"]
    subscriptions = item.get("subscriptions", [])

    if topic not in subscriptions:
        subscriptions.append(topic)
        connections_table.update_item(
            Key={"connectionId": connection_id},
            UpdateExpression="SET subscriptions = :subs",
            ExpressionAttributeValues={":subs": subscriptions},
        )

    # Confirmar subscrição
    send_message(
        apigateway,
        connection_id,
        {
            "type": "subscription_confirmed",
            "topic": topic,
            "subscriptions": subscriptions,
        },
    )

    print(f"Subscrito no tópico {topic}: {connection_id}")
    return {"statusCode": 200}


def handle_unsubscribe(event, connection_id, apigateway):
    """Processar desinscrição"""
    body = json.loads(event.get("body", "{}"))
    topic = body.get("topic")

    if not topic:
        return {"statusCode": 400}

    # Buscar e atualizar subscrições
    response = connections_table.get_item(Key={"connectionId": connection_id})
    if "Item" not in response:
        return {"statusCode": 404}

    subscriptions = response["Item"].get("subscriptions", [])
    if topic in subscriptions:
        subscriptions.remove(topic)
        connections_table.update_item(
            Key={"connectionId": connection_id},
            UpdateExpression="SET subscriptions = :subs",
            ExpressionAttributeValues={":subs": subscriptions},
        )

    send_message(
        apigateway,
        connection_id,
        {
            "type": "unsubscription_confirmed",
            "topic": topic,
            "subscriptions": subscriptions,
        },
    )

    return {"statusCode": 200}


def send_message(apigateway, connection_id, message):
    """Enviar mensagem para conexão"""
    try:
        apigateway.post_to_connection(
            ConnectionId=connection_id, Data=json.dumps(message)
        )
    except apigateway.exceptions.GoneException:
        # Conexão morta, remover do banco
        connections_table.delete_item(Key={"connectionId": connection_id})
        print(f"Conexão morta removida: {connection_id}")
    except Exception as e:
        print(f"Erro ao enviar mensagem: {str(e)}")
