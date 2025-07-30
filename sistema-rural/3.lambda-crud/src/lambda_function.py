import json
import boto3
import uuid
import os
import base64
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
analysis_table_name = os.environ.get("PROPERTY_ANALYSIS_TABLE", "")
table = dynamodb.Table(table_name)
analysis_table = dynamodb.Table(analysis_table_name) if analysis_table_name else None
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
        elif method == "POST" and "/properties/report" in resource:
            return generate_properties_report(event, user_id)
        elif method == "GET" and "/properties" in resource and "/analysis" in resource:
            return get_property_analysis(event, user_id)
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


def generate_properties_report(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Gera relatório PDF das propriedades selecionadas"""
    try:
        body = json.loads(event.get("body", "{}"))
        property_ids = body.get("propertyIds", [])

        if not property_ids:
            return create_response(
                400, {"error": "IDs das propriedades são obrigatórios"}
            )

        # Buscar propriedades
        selected_properties = []
        for prop_id in property_ids:
            try:
                response = table.get_item(
                    Key={"userId": user_id, "propertyId": prop_id}
                )
                if "Item" in response:
                    selected_properties.append(response["Item"])
            except Exception as e:
                print(f"Erro ao buscar propriedade {prop_id}: {str(e)}")
                continue

        if not selected_properties:
            return create_response(404, {"error": "Nenhuma propriedade encontrada"})

        # Gerar PDF
        pdf_data = generate_pdf_report(selected_properties, user_id)
        filename = (
            f"relatorio_propriedades_{datetime.now().strftime('%Y%m%d_%H%M%S')}.pdf"
        )

        return create_response(
            200,
            {
                "message": "Relatório gerado com sucesso",
                "pdf": pdf_data,
                "filename": filename,
                "properties_count": len(selected_properties),
            },
        )

    except Exception as e:
        print(f"Error in generate_properties_report: {str(e)}")
        return create_response(500, {"error": f"Erro ao gerar relatório: {str(e)}"})


def get_property_analysis(event: Dict[str, Any], user_id: str) -> Dict[str, Any]:
    """Busca análise de uma propriedade específica"""
    try:
        property_id = event["pathParameters"]["id"]

        # Verificar se a propriedade pertence ao usuário
        property_response = table.get_item(
            Key={"userId": user_id, "propertyId": property_id}
        )

        if "Item" not in property_response:
            return create_response(404, {"error": "Propriedade não encontrada"})

        # Buscar análise na tabela de análises
        if analysis_table:
            analysis_response = analysis_table.get_item(Key={"propertyId": property_id})

            if "Item" in analysis_response:
                analysis_data = format_analysis_for_response(analysis_response["Item"])
                return create_response(
                    200, {"propertyId": property_id, "analysis": analysis_data}
                )

        # Se não encontrou análise específica, retornar status da propriedade
        property_item = property_response["Item"]
        return create_response(
            200,
            {
                "propertyId": property_id,
                "analysis": {
                    "analysisStatus": property_item.get("analysisStatus", "pending"),
                    "message": "Análise ainda não disponível",
                },
            },
        )

    except Exception as e:
        print(f"Error in get_property_analysis: {str(e)}")
        return create_response(500, {"error": "Erro ao buscar análise"})


def generate_pdf_report(properties: List[Dict[str, Any]], user_id: str) -> str:
    """Gera relatório PDF usando ReportLab"""
    try:
        from reportlab.lib.pagesizes import letter
        from reportlab.platypus import (
            SimpleDocTemplate,
            Paragraph,
            Spacer,
            Table,
            TableStyle,
        )
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import inch
        from reportlab.lib import colors
        from reportlab.lib.enums import TA_CENTER, TA_LEFT
        import io

        # Criar buffer para PDF
        buffer = io.BytesIO()

        # Criar documento
        doc = SimpleDocTemplate(
            buffer,
            pagesize=letter,
            rightMargin=72,
            leftMargin=72,
            topMargin=72,
            bottomMargin=18,
        )

        # Estilos
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            "CustomTitle",
            parent=styles["Heading1"],
            fontSize=24,
            spaceAfter=30,
            alignment=TA_CENTER,
        )

        subtitle_style = ParagraphStyle(
            "CustomSubtitle",
            parent=styles["Heading2"],
            fontSize=16,
            spaceAfter=20,
            alignment=TA_LEFT,
        )

        # Conteúdo do PDF
        story = []

        # Título
        story.append(Paragraph("Relatório de Propriedades Rurais", title_style))
        story.append(Spacer(1, 12))

        # Data de geração
        now = datetime.now(timezone.utc)
        story.append(
            Paragraph(
                f"Gerado em: {now.strftime('%d/%m/%Y %H:%M:%S')}", styles["Normal"]
            )
        )
        story.append(
            Paragraph(f"Total de propriedades: {len(properties)}", styles["Normal"])
        )
        story.append(Spacer(1, 20))

        # Resumo geral
        total_area = sum(float(prop.get("area", 0)) for prop in properties)
        total_perimeter = sum(float(prop.get("perimeter", 0)) for prop in properties)

        summary_data = [
            ["Métrica", "Valor"],
            ["Propriedades", str(len(properties))],
            ["Área Total", f"{total_area:.2f} hectares"],
            ["Perímetro Total", f"{total_perimeter/1000:.2f} km"],
            [
                "Área Média",
                f"{total_area/len(properties):.2f} hectares" if properties else "0",
            ],
        ]

        summary_table = Table(summary_data, colWidths=[2 * inch, 2 * inch])
        summary_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, 0), 14),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 12),
                    ("BACKGROUND", (0, 1), (-1, -1), colors.beige),
                    ("GRID", (0, 0), (-1, -1), 1, colors.black),
                ]
            )
        )

        story.append(Paragraph("Resumo Geral", subtitle_style))
        story.append(summary_table)
        story.append(Spacer(1, 20))

        # Detalhes das propriedades
        story.append(Paragraph("Detalhes das Propriedades", subtitle_style))

        # Tabela de propriedades
        table_data = [["Nome", "Tipo", "Área (ha)", "Perímetro (m)", "Status"]]

        for prop in properties:
            table_data.append(
                [
                    prop.get("name", "N/A"),
                    prop.get("type", "N/A").capitalize(),
                    f"{float(prop.get('area', 0)):.2f}",
                    f"{float(prop.get('perimeter', 0)):.0f}",
                    prop.get("analysisStatus", "pending").capitalize(),
                ]
            )

        properties_table = Table(
            table_data, colWidths=[1.5 * inch, 1 * inch, 1 * inch, 1 * inch, 1 * inch]
        )
        properties_table.setStyle(
            TableStyle(
                [
                    ("BACKGROUND", (0, 0), (-1, 0), colors.grey),
                    ("TEXTCOLOR", (0, 0), (-1, 0), colors.whitesmoke),
                    ("ALIGN", (0, 0), (-1, -1), "CENTER"),
                    ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
                    ("FONTSIZE", (0, 0), (-1, 0), 12),
                    ("BOTTOMPADDING", (0, 0), (-1, 0), 12),
                    ("BACKGROUND", (0, 1), (-1, -1), colors.beige),
                    ("GRID", (0, 0), (-1, -1), 1, colors.black),
                    ("FONTSIZE", (0, 1), (-1, -1), 10),
                ]
            )
        )

        story.append(properties_table)
        story.append(Spacer(1, 20))

        # Rodapé
        story.append(Spacer(1, 30))
        story.append(
            Paragraph("Sistema Rural - Gestão de Propriedades", styles["Normal"])
        )
        story.append(Paragraph("Relatório gerado automaticamente", styles["Normal"]))

        # Gerar PDF
        doc.build(story)

        # Converter para base64
        pdf_bytes = buffer.getvalue()
        buffer.close()

        return base64.b64encode(pdf_bytes).decode("utf-8")

    except ImportError:
        # Fallback se ReportLab não estiver disponível
        print("ReportLab não encontrado, gerando relatório texto simples")
        return generate_simple_text_report(properties, user_id)

    except Exception as e:
        print(f"Erro ao gerar PDF: {str(e)}")
        return generate_simple_text_report(properties, user_id)


def generate_simple_text_report(properties: List[Dict[str, Any]], user_id: str) -> str:
    """Gera relatório simples em texto como fallback"""
    try:
        import io

        buffer = io.StringIO()
        buffer.write("RELATÓRIO DE PROPRIEDADES RURAIS\n")
        buffer.write("=" * 50 + "\n\n")

        now = datetime.now(timezone.utc)
        buffer.write(f"Gerado em: {now.strftime('%d/%m/%Y %H:%M:%S')}\n")
        buffer.write(f"Total de propriedades: {len(properties)}\n\n")

        total_area = sum(float(prop.get("area", 0)) for prop in properties)
        total_perimeter = sum(float(prop.get("perimeter", 0)) for prop in properties)

        buffer.write("RESUMO GERAL:\n")
        buffer.write(f"- Área Total: {total_area:.2f} hectares\n")
        buffer.write(f"- Perímetro Total: {total_perimeter/1000:.2f} km\n")
        buffer.write(f"- Área Média: {total_area/len(properties):.2f} hectares\n\n")

        buffer.write("PROPRIEDADES:\n")
        buffer.write("-" * 50 + "\n")

        for i, prop in enumerate(properties, 1):
            buffer.write(f"{i}. {prop.get('name', 'N/A')}\n")
            buffer.write(f"   Tipo: {prop.get('type', 'N/A').capitalize()}\n")
            buffer.write(f"   Área: {float(prop.get('area', 0)):.2f} hectares\n")
            buffer.write(
                f"   Perímetro: {float(prop.get('perimeter', 0)):.0f} metros\n"
            )
            buffer.write(
                f"   Status: {prop.get('analysisStatus', 'pending').capitalize()}\n"
            )
            if prop.get("description"):
                buffer.write(f"   Descrição: {prop['description']}\n")
            buffer.write("\n")

        buffer.write("\nSistema Rural - Gestão de Propriedades\n")

        # Converter para base64 (simular PDF)
        text_content = buffer.getvalue()
        buffer.close()

        return base64.b64encode(text_content.encode("utf-8")).decode("utf-8")

    except Exception as e:
        print(f"Erro ao gerar relatório texto: {str(e)}")
        # Retornar algo básico
        basic_report = f"Relatório das {len(properties)} propriedades selecionadas"
        return base64.b64encode(basic_report.encode("utf-8")).decode("utf-8")


def format_analysis_for_response(analysis_item: Dict[str, Any]) -> Dict[str, Any]:
    """Formata dados de análise para resposta da API"""

    def convert_decimal_to_float(obj):
        if isinstance(obj, Decimal):
            return float(obj)
        elif isinstance(obj, dict):
            return {k: convert_decimal_to_float(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_decimal_to_float(v) for v in obj]
        return obj

    return {
        "propertyId": analysis_item.get("propertyId"),
        "analysisStatus": analysis_item.get("analysisStatus", "pending"),
        "analysisResults": convert_decimal_to_float(
            analysis_item.get("analysisResults", {})
        ),
        "createdAt": analysis_item.get("createdAt"),
        "updatedAt": analysis_item.get("updatedAt"),
        "completedAt": analysis_item.get("completedAt"),
    }


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
        return create_response(201, {"property": response_property})

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
        existing_property = table.get_item(
            Key={"userId": user_id, "propertyId": property_id}
        )
        if "Item" not in existing_property:
            return create_response(404, {"error": "Propriedade não encontrada"})

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
            Key={"userId": user_id, "propertyId": property_id},
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
        return create_response(200, {"property": response_property})

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
        existing_property = table.get_item(
            Key={"userId": user_id, "propertyId": property_id}
        )
        if "Item" not in existing_property:
            return create_response(404, {"error": "Propriedade não encontrada"})

        # Delete property
        table.delete_item(Key={"userId": user_id, "propertyId": property_id})

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
