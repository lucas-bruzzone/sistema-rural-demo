import json
import boto3
import uuid
import os
from datetime import datetime, timezone
from typing import Dict, Any, List
from decimal import Decimal
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key

# AWS clients
dynamodb = boto3.resource("dynamodb")
eventbridge = boto3.client("events")

# Environment variables
table_name = os.environ.get("PROPERTIES_TABLE")
table = dynamodb.Table(table_name)
eventbus_name = os.environ.get("EVENTBRIDGE_BUS_NAME", "")


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Router principal para CRUD de propriedades"""
    try:
        method = event.get("httpMethod", "")
        path = event.get("path", "")
        resource = event.get("resource", "")

        user_id = extract_user_id(event)
        if not user_id:
            return create_response(401, {"error": "Token inválido"})

        # Routes
        if method == "POST" and "/properties/import" in resource:
            return import_properties_bulk(event, user_id)
        elif method == "POST" and "/properties" in resource and "{id}" not in resource:
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
        print(f"Error in lambda_handler: {str(e)}")
        return create_response(500, {"error": "Erro interno do servidor"})


def import_properties_bulk(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Importa propriedades em lote via CSV"""
    try:
        body = json.loads(event.get("body", "{}"))
        properties_data = body.get("properties", [])

        if not properties_data:
            return create_response(400, {"error": "Nenhuma propriedade fornecida"})

        imported_count = 0
        errors = []

        for i, property_data in enumerate(properties_data):
            try:
                # Validate property data
                validation_result = validate_property_data(property_data)
                if not validation_result["valid"]:
                    errors.append(f"Propriedade {i+1}: {validation_result['message']}")
                    continue

                # Create property ID
                property_id = str(uuid.uuid4())
                now = datetime.now(timezone.utc).isoformat()

                # Prepare coordinates for DynamoDB
                coordinates_decimal = convert_coordinates_to_decimal(
                    property_data.get("coordinates", [])
                )

                # Prepare item for DynamoDB
                item = {
                    "propertyId": property_id,
                    "userId": user_id,
                    "name": property_data["name"],
                    "type": property_data.get("type", "farm"),
                    "description": property_data.get("description", ""),
                    "area": Decimal(str(property_data.get("area", 0))),
                    "perimeter": Decimal(str(property_data.get("perimeter", 0))),
                    "coordinates": coordinates_decimal,
                    "analysisStatus": "pending",
                    "createdAt": now,
                    "updatedAt": now,
                }

                # Save to DynamoDB
                table.put_item(Item=item)

                # Publish event to EventBridge
                publish_property_event(property_id, user_id, item, "Property Created")

                imported_count += 1

            except Exception as property_error:
                errors.append(f"Propriedade {i+1}: {str(property_error)}")
                continue

        response_data = {
            "imported": imported_count,
            "total": len(properties_data),
            "errors": errors,
        }

        return create_response(200, response_data)

    except Exception as e:
        print(f"Error in import_properties_bulk: {str(e)}")
        return create_response(500, {"error": f"Erro na importação: {str(e)}"})


def create_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Cria nova propriedade"""
    try:
        body = json.loads(event.get("body", "{}"))

        validation_result = validate_property_data(body)
        if not validation_result["valid"]:
            return create_response(400, {"error": validation_result["message"]})

        property_id = str(uuid.uuid4())
        now = datetime.now(timezone.utc).isoformat()

        # Convert coordinates to Decimal for DynamoDB
        coordinates_decimal = convert_coordinates_to_decimal(
            body.get("coordinates", [])
        )

        item = {
            "propertyId": property_id,
            "userId": user_id,
            "name": body["name"],
            "type": body.get("type", "farm"),
            "description": body.get("description", ""),
            "area": Decimal(str(body.get("area", 0))),
            "perimeter": Decimal(str(body.get("perimeter", 0))),
            "coordinates": coordinates_decimal,
            "analysisStatus": "pending",
            "createdAt": now,
            "updatedAt": now,
        }

        table.put_item(Item=item)

        # Publish event to EventBridge
        publish_property_event(property_id, user_id, item, "Property Created")

        response_property = format_property_for_response(item)
        return create_response(201, response_property)

    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return create_response(500, {"error": "Erro ao salvar propriedade"})
    except Exception as e:
        print(f"Error in create_property: {str(e)}")
        return create_response(500, {"error": "Erro interno do servidor"})


def get_properties(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Lista propriedades do usuário"""
    try:
        # Query directly on the main table since userId is the hash key
        response = table.query(
            KeyConditionExpression=Key("userId").eq(user_id),
            ScanIndexForward=False,  # Order by propertyId desc
        )

        properties = [
            format_property_for_response(item) for item in response.get("Items", [])
        ]

        return create_response(
            200, {"properties": properties, "count": len(properties)}
        )

    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return create_response(500, {"error": "Erro ao buscar propriedades"})
    except Exception as e:
        print(f"Error in get_properties: {str(e)}")
        return create_response(500, {"error": "Erro interno do servidor"})


def update_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Atualiza propriedade existente"""
    try:
        property_id = event["pathParameters"]["id"]
        body = json.loads(event.get("body", "{}"))

        # Validate property data
        validation_result = validate_property_data(body)
        if not validation_result["valid"]:
            return create_response(400, {"error": validation_result["message"]})

        # Check if property exists and belongs to user
        existing_property = table.get_item(Key={"propertyId": property_id})
        if "Item" not in existing_property:
            return create_response(404, {"error": "Propriedade não encontrada"})

        if existing_property["Item"]["userId"] != user_id:
            return create_response(403, {"error": "Acesso negado"})

        # Update timestamp
        now = datetime.now(timezone.utc).isoformat()

        # Convert coordinates to Decimal
        coordinates_decimal = convert_coordinates_to_decimal(
            body.get("coordinates", [])
        )

        # Update item
        update_expression = "SET #name = :name, #type = :type, description = :desc, area = :area, perimeter = :perimeter, coordinates = :coords, updatedAt = :updatedAt"
        expression_attribute_names = {"#name": "name", "#type": "type"}
        expression_attribute_values = {
            ":name": body["name"],
            ":type": body.get("type", "farm"),
            ":desc": body.get("description", ""),
            ":area": Decimal(str(body.get("area", 0))),
            ":perimeter": Decimal(str(body.get("perimeter", 0))),
            ":coords": coordinates_decimal,
            ":updatedAt": now,
        }

        response = table.update_item(
            Key={"propertyId": property_id},
            UpdateExpression=update_expression,
            ExpressionAttributeNames=expression_attribute_names,
            ExpressionAttributeValues=expression_attribute_values,
            ReturnValues="ALL_NEW",
        )

        updated_property = response["Attributes"]

        # Publish event to EventBridge
        publish_property_event(
            property_id, user_id, updated_property, "Property Updated"
        )

        response_property = format_property_for_response(updated_property)
        return create_response(200, response_property)

    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return create_response(500, {"error": "Erro ao atualizar propriedade"})
    except Exception as e:
        print(f"Error in update_property: {str(e)}")
        return create_response(500, {"error": "Erro interno do servidor"})


def delete_property(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Remove propriedade"""
    try:
        property_id = event["pathParameters"]["id"]

        # Check if property exists and belongs to user
        existing_property = table.get_item(Key={"propertyId": property_id})
        if "Item" not in existing_property:
            return create_response(404, {"error": "Propriedade não encontrada"})

        if existing_property["Item"]["userId"] != user_id:
            return create_response(403, {"error": "Acesso negado"})

        # Delete property
        table.delete_item(Key={"propertyId": property_id})

        # Publish event to EventBridge
        publish_property_event(
            property_id, user_id, existing_property["Item"], "Property Deleted"
        )

        return create_response(200, {"message": "Propriedade removida com sucesso"})

    except ClientError as e:
        print(f"DynamoDB error: {str(e)}")
        return create_response(500, {"error": "Erro ao remover propriedade"})
    except Exception as e:
        print(f"Error in delete_property: {str(e)}")
        return create_response(500, {"error": "Erro interno do servidor"})


def publish_property_event(
    property_id: str, user_id: str, property_data: Dict[str, Any], event_type: str
):
    """Publica evento no EventBridge"""
    try:
        if not eventbus_name:
            print("EventBridge bus name not configured, skipping event publication")
            return

        # Prepare event details
        event_detail = {
            "propertyId": property_id,
            "userId": user_id,
            "name": property_data.get("name"),
            "type": property_data.get("type"),
            "area": float(property_data.get("area", 0)),
            "coordinates": [
                [float(coord[0]), float(coord[1])]
                for coord in property_data.get("coordinates", [])
            ],
            "status": (
                "created"
                if "Created" in event_type
                else "updated" if "Updated" in event_type else "deleted"
            ),
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        # Publish to EventBridge
        response = eventbridge.put_events(
            Entries=[
                {
                    "Source": "property.service",
                    "DetailType": event_type,
                    "Detail": json.dumps(event_detail),
                    "EventBusName": eventbus_name,
                }
            ]
        )

        print(
            f"Event published to EventBridge: {event_type} for property {property_id}"
        )
        return response

    except Exception as e:
        print(f"Error publishing event to EventBridge: {str(e)}")
        # Don't fail the main operation if event publication fails


def extract_user_id(event: Dict[str, Any]) -> str:
    """Extrai user_id do token JWT via API Gateway authorizer"""
    try:
        request_context = event.get("requestContext", {})
        authorizer = request_context.get("authorizer", {})

        # Try different possible locations for userId
        user_id = (
            authorizer.get("userId")
            or authorizer.get("user_id")
            or authorizer.get("claims", {}).get("sub")
            or authorizer.get("principalId")
        )

        return user_id
    except Exception as e:
        print(f"Error extracting user_id: {str(e)}")
        return None


def validate_property_data(data: Dict[str, Any]) -> Dict[str, Any]:
    """Valida dados da propriedade"""
    if not data.get("name") or len(data["name"].strip()) < 2:
        return {"valid": False, "message": "Nome deve ter pelo menos 2 caracteres"}

    try:
        area = float(data.get("area", 0))
        if area <= 0:
            return {"valid": False, "message": "Área deve ser maior que zero"}
    except (ValueError, TypeError):
        return {"valid": False, "message": "Área deve ser um número válido"}

    # Validate coordinates if provided
    coordinates = data.get("coordinates", [])
    if coordinates:
        if not isinstance(coordinates, list) or len(coordinates) < 3:
            return {
                "valid": False,
                "message": "Coordenadas devem ser uma lista com pelo menos 3 pontos",
            }

        for i, coord in enumerate(coordinates):
            if not isinstance(coord, list) or len(coord) != 2:
                return {
                    "valid": False,
                    "message": f"Coordenada {i+1} deve ter formato [longitude, latitude]",
                }

            try:
                float(coord[0])  # longitude
                float(coord[1])  # latitude
            except (ValueError, TypeError):
                return {
                    "valid": False,
                    "message": f"Coordenada {i+1} deve conter números válidos",
                }

    return {"valid": True, "message": "Dados válidos"}


def convert_coordinates_to_decimal(coordinates):
    """Converte coordenadas para Decimal para DynamoDB"""
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
