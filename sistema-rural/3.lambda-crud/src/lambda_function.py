import json
import boto3
import uuid
import os
from datetime import datetime, timezone
from typing import Dict, Any
from decimal import Decimal
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key

# AWS clients
dynamodb = boto3.resource("dynamodb")
table_name = os.environ.get("PROPERTIES_TABLE")
table = dynamodb.Table(table_name)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Router principal para CRUD de propriedades"""
    try:
        method = event.get("httpMethod", "")
        path = event.get("path", "")
        resource = event.get("resource", "")

        user_id = extract_user_id(event)
        if not user_id:
            return create_response(401, {"error": "Token inválido"})

        if method == "POST" and "/properties" in resource and "{id}" not in resource:
            return create_property(event, user_id)
        elif method == "GET" and "/properties" in resource and "{id}" not in resource:
            return get_properties(event, user_id)
        elif method == "PUT" and "/properties" in resource and "{id}" in resource:
            return update_property(event, user_id)
        elif method == "DELETE" and "/properties" in resource and "{id}" in resource:
            return delete_property(event, user_id)
        elif method == "OPTIONS":
            return create_response(200, {"message": "CORS preflight"})
        else:
            return create_response(
                404, {"error": f"Endpoint não encontrado: {method} {resource}"}
            )

    except Exception as e:
        return create_response(500, {"error": "Erro interno do servidor"})


def create_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Cria nova propriedade"""
    try:
        body = json.loads(event.get("body", "{}"))

        validation_result = validate_property_data(body)
        if not validation_result["valid"]:
            return create_response(400, {"error": validation_result["message"]})

        property_id = f"prop_{uuid.uuid4().hex[:12]}"
        current_time = datetime.now(timezone.utc).isoformat()

        property_item = {
            "userId": user_id,
            "propertyId": property_id,
            "name": body["name"],
            "type": body.get("type", "fazenda"),
            "description": body.get("description", ""),
            "area": Decimal(str(body["area"])),
            "perimeter": Decimal(str(body["perimeter"])),
            "coordinates": convert_coordinates_to_decimal(body["coordinates"]),
            "analysisStatus": "pending",
            "createdAt": current_time,
            "updatedAt": current_time,
        }

        table.put_item(Item=property_item)
        formatted_property = format_property_for_response(property_item)

        return create_response(
            201,
            {
                "message": "Propriedade criada com sucesso",
                "property": formatted_property,
            },
        )

    except Exception as e:
        return create_response(500, {"error": "Erro ao criar propriedade"})


def get_properties(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Lista propriedades do usuário"""
    try:
        query_params = event.get("queryStringParameters") or {}
        limit = int(query_params.get("limit", 50))

        response = table.query(
            KeyConditionExpression=Key("userId").eq(user_id),
            Limit=min(limit, 100),
            ScanIndexForward=False,
        )

        properties = [
            format_property_for_response(item) for item in response.get("Items", [])
        ]

        return create_response(
            200, {"properties": properties, "count": len(properties)}
        )

    except Exception as e:
        return create_response(500, {"error": "Erro ao buscar propriedades"})


def update_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Atualiza propriedade existente"""
    try:
        path_parameters = event.get("pathParameters") or {}
        property_id = path_parameters.get("id")

        if not property_id:
            return create_response(400, {"error": "ID da propriedade é obrigatório"})

        body = json.loads(event.get("body", "{}"))

        # Verificar se propriedade existe
        existing = table.get_item(Key={"userId": user_id, "propertyId": property_id})
        if "Item" not in existing:
            return create_response(404, {"error": "Propriedade não encontrada"})

        # Construir update expression
        update_expression = "SET updatedAt = :updatedAt"
        expression_values = {":updatedAt": datetime.now(timezone.utc).isoformat()}

        if "name" in body:
            update_expression += ", #name = :name"
            expression_values[":name"] = body["name"]

        if "type" in body:
            update_expression += ", #type = :type"
            expression_values[":type"] = body["type"]

        if "description" in body:
            update_expression += ", description = :description"
            expression_values[":description"] = body["description"]

        if "area" in body:
            update_expression += ", area = :area"
            expression_values[":area"] = Decimal(str(body["area"]))

        if "perimeter" in body:
            update_expression += ", perimeter = :perimeter"
            expression_values[":perimeter"] = Decimal(str(body["perimeter"]))

        if "coordinates" in body:
            update_expression += ", coordinates = :coordinates"
            expression_values[":coordinates"] = convert_coordinates_to_decimal(
                body["coordinates"]
            )

        response = table.update_item(
            Key={"userId": user_id, "propertyId": property_id},
            UpdateExpression=update_expression,
            ExpressionAttributeValues=expression_values,
            ExpressionAttributeNames={"#name": "name", "#type": "type"},
            ReturnValues="ALL_NEW",
        )

        formatted_property = format_property_for_response(response["Attributes"])

        return create_response(
            200,
            {
                "message": "Propriedade atualizada com sucesso",
                "property": formatted_property,
            },
        )

    except Exception as e:
        return create_response(500, {"error": "Erro ao atualizar propriedade"})


def delete_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Deleta propriedade"""
    try:
        path_parameters = event.get("pathParameters") or {}
        property_id = path_parameters.get("id")

        if not property_id:
            return create_response(400, {"error": "ID da propriedade é obrigatório"})

        table.delete_item(
            Key={"userId": user_id, "propertyId": property_id},
            ConditionExpression="attribute_exists(userId) AND attribute_exists(propertyId)",
        )

        return create_response(
            200,
            {
                "message": "Propriedade deletada com sucesso",
                "deletedProperty": {"id": property_id},
            },
        )

    except ClientError as e:
        if e.response["Error"]["Code"] == "ConditionalCheckFailedException":
            return create_response(404, {"error": "Propriedade não encontrada"})
        return create_response(500, {"error": "Erro ao deletar propriedade"})


# Funções auxiliares
def extract_user_id(event: Dict[str, Any]) -> str:
    """Extrai user ID do contexto do Cognito"""
    try:
        authorizer_context = event.get("requestContext", {}).get("authorizer", {})
        return authorizer_context.get("claims", {}).get(
            "sub"
        ) or authorizer_context.get("sub")
    except:
        return None


def validate_property_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Valida dados da propriedade"""
    required_fields = ["name", "area", "perimeter", "coordinates"]

    for field in required_fields:
        if field not in data:
            return {"valid": False, "message": f"Campo obrigatório: {field}"}

    if not data["name"].strip() or len(data["name"]) < 2:
        return {"valid": False, "message": "Nome deve ter pelo menos 2 caracteres"}

    try:
        area = float(data["area"])
        if area <= 0:
            return {"valid": False, "message": "Área deve ser maior que zero"}
    except:
        return {"valid": False, "message": "Área deve ser um número válido"}

    return {"valid": True, "message": "Dados válidos"}


def convert_coordinates_to_decimal(coordinates):
    """Converte coordenadas para Decimal"""
    if not isinstance(coordinates, list):
        return coordinates
    return [
        [Decimal(str(coord[0])), Decimal(str(coord[1]))]
        for coord in coordinates
        if len(coord) == 2
    ]


def format_property_for_response(property_item: Dict[str, Any]) -> Dict[str, Any]:
    """Formata propriedade para resposta da API"""
    return {
        "id": property_item.get("propertyId"),
        "name": property_item.get("name"),
        "type": property_item.get("type"),
        "description": property_item.get("description", ""),
        "area": float(property_item.get("area", 0)),
        "perimeter": float(property_item.get("perimeter", 0)),
        "coordinates": [
            [float(coord[0]), float(coord[1])]
            for coord in property_item.get("coordinates", [])
        ],
        "analysisStatus": property_item.get("analysisStatus", "pending"),
        "createdAt": property_item.get("createdAt"),
        "updatedAt": property_item.get("updatedAt"),
    }


def create_response(status_code: int, body: Dict[str, Any]) -> Dict[str, Any]:
    """Cria resposta HTTP padronizada"""
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Headers": "Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token",
            "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE,OPTIONS",
        },
        "body": json.dumps(body, ensure_ascii=False, default=str),
    }
