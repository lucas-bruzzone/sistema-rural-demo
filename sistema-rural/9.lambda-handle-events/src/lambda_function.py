import json
import boto3
import os
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List
from botocore.exceptions import ClientError

# Configure logging for CloudWatch
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# AWS clients
dynamodb = boto3.resource("dynamodb")

# Environment variables
CONNECTIONS_TABLE = os.environ["WEBSOCKET_TABLE"]
WEBSOCKET_ENDPOINT = os.environ["WEBSOCKET_API_ENDPOINT"]

# DynamoDB table
connections_table = dynamodb.Table(CONNECTIONS_TABLE)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Handle EventBridge events and send WebSocket notifications"""

    logger.info(f"Lambda started - Event: {json.dumps(event, default=str)}")

    try:
        processed_events = 0

        # Process each EventBridge record
        for record in event.get("Records", []):
            # EventBridge events come directly, not in Records
            if "source" in event:
                process_eventbridge_event(event)
                processed_events += 1
            elif "detail" in record:
                process_eventbridge_event(record)
                processed_events += 1

        # If direct EventBridge event (not SQS wrapped)
        if "source" in event:
            process_eventbridge_event(event)
            processed_events += 1

        logger.info(f"Successfully processed {processed_events} events")
        return {"statusCode": 200, "body": "Notifications processed"}

    except Exception as e:
        logger.error(f"Error processing notifications: {str(e)}", exc_info=True)
        return {"statusCode": 500, "body": str(e)}


def process_eventbridge_event(event: Dict[str, Any]) -> None:
    """Process individual EventBridge event"""

    try:
        source = event.get("source")
        detail_type = event.get("detail-type")
        detail = event.get("detail", {})

        logger.info(
            f"Processing EventBridge event - Source: {source}, Type: {detail_type}, Detail: {json.dumps(detail, default=str)}"
        )

        # Route based on event type
        if source == "property.service":
            handle_property_event(detail_type, detail)
        elif source == "geospatial.analysis":
            handle_analysis_event(detail_type, detail)
        else:
            logger.warning(f"Unknown event source: {source}")

    except Exception as e:
        logger.error(f"Error processing EventBridge event: {str(e)}", exc_info=True)


def handle_property_event(detail_type: str, detail: Dict[str, Any]) -> None:
    """Handle property-related events"""

    try:
        property_id = detail.get("propertyId")
        user_id = detail.get("userId")

        logger.info(
            f"Handling property event - Type: {detail_type}, PropertyID: {property_id}, UserID: {user_id}"
        )

        if not property_id or not user_id:
            logger.error(
                f"Missing required fields - PropertyID: {property_id}, UserID: {user_id}"
            )
            return

        if detail_type == "Property Created":
            message = {
                "type": "property_notification",
                "event": "created",
                "propertyId": property_id,
                "message": f"Nova propriedade criada: {property_id}",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "data": detail,
            }

        elif detail_type == "Property Updated":
            message = {
                "type": "property_notification",
                "event": "updated",
                "propertyId": property_id,
                "message": f"Propriedade atualizada: {property_id}",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "data": detail,
            }

        else:
            logger.warning(f"Unknown property event type: {detail_type}")
            return

        # Send to user
        user_sent = send_notification_to_user(user_id, message)
        logger.info(f"Sent property notification to {user_sent} user connections")

        # Send to property subscribers
        topic_sent = send_notification_to_topic(f"property.{property_id}", message)
        logger.info(f"Sent property notification to {topic_sent} topic subscribers")

    except Exception as e:
        logger.error(f"Error handling property event: {str(e)}", exc_info=True)


def handle_analysis_event(detail_type: str, detail: Dict[str, Any]) -> None:
    """Handle analysis-related events"""

    try:
        property_id = detail.get("propertyId")

        logger.info(
            f"Handling analysis event - Type: {detail_type}, PropertyID: {property_id}"
        )

        if not property_id:
            logger.error(f"Missing propertyId in analysis event: {detail}")
            return

        if detail_type == "Analysis Completed":
            message = {
                "type": "analysis_notification",
                "event": "completed",
                "propertyId": property_id,
                "message": f"Análise geoespacial concluída para propriedade {property_id}",
                "timestamp": datetime.now(timezone.utc).isoformat(),
                "data": detail,
            }

            # Get property owner from detail or query database
            user_id = detail.get("userId")
            if user_id:
                user_sent = send_notification_to_user(user_id, message)
                logger.info(
                    f"Sent analysis notification to {user_sent} user connections"
                )

            # Send to analysis subscribers
            topic1_sent = send_notification_to_topic("analysis.completed", message)
            topic2_sent = send_notification_to_topic(
                f"property.{property_id}.analysis", message
            )
            logger.info(
                f"Sent analysis notification to {topic1_sent + topic2_sent} topic subscribers"
            )

        else:
            logger.warning(f"Unknown analysis event type: {detail_type}")

    except Exception as e:
        logger.error(f"Error handling analysis event: {str(e)}", exc_info=True)


def send_notification_to_user(user_id: str, message: Dict[str, Any]) -> int:
    """Send notification to all connections of a specific user"""

    try:
        logger.info(f"Sending notification to user: {user_id}")

        # Query connections by user ID
        response = connections_table.query(
            IndexName="UserIdIndex",
            KeyConditionExpression="userId = :user_id",
            ExpressionAttributeValues={":user_id": user_id},
        )

        connections = response.get("Items", [])
        logger.info(f"Found {len(connections)} connections for user {user_id}")

        successful_sends = 0

        for connection in connections:
            connection_id = connection["connectionId"]
            if send_message_to_connection(connection_id, message):
                successful_sends += 1

        logger.info(
            f"Successfully sent notification to {successful_sends}/{len(connections)} connections for user {user_id}"
        )
        return successful_sends

    except Exception as e:
        logger.error(
            f"Error sending notification to user {user_id}: {e}", exc_info=True
        )
        return 0


def send_notification_to_topic(topic: str, message: Dict[str, Any]) -> int:
    """Send notification to all subscribers of a topic"""

    try:
        logger.info(f"Sending notification to topic: {topic}")

        # Scan for connections subscribed to topic
        scan_response = connections_table.scan(
            FilterExpression="contains(subscriptions, :topic)",
            ExpressionAttributeValues={":topic": topic},
        )

        connections = scan_response.get("Items", [])
        logger.info(f"Found {len(connections)} subscribers for topic {topic}")

        successful_sends = 0

        for connection in connections:
            connection_id = connection["connectionId"]
            if send_message_to_connection(connection_id, message):
                successful_sends += 1

        logger.info(
            f"Successfully sent notification to {successful_sends}/{len(connections)} subscribers of topic {topic}"
        )
        return successful_sends

    except Exception as e:
        logger.error(f"Error sending notification to topic {topic}: {e}", exc_info=True)
        return 0


def send_message_to_connection(connection_id: str, message: Dict[str, Any]) -> bool:
    """Send message to specific WebSocket connection"""

    try:
        # Initialize API Gateway Management API client with endpoint
        endpoint_url = WEBSOCKET_ENDPOINT.replace("wss://", "https://")
        apigateway_client = boto3.client(
            "apigatewaymanagementapi", endpoint_url=endpoint_url
        )

        # Send message
        apigateway_client.post_to_connection(
            ConnectionId=connection_id, Data=json.dumps(message)
        )

        logger.debug(f"Message sent successfully to connection {connection_id}")
        return True

    except ClientError as e:
        error_code = e.response["Error"]["Code"]

        if error_code == "GoneException":
            # Connection is stale, remove from DynamoDB
            logger.warning(f"Stale connection detected and removing: {connection_id}")
            try:
                connections_table.delete_item(Key={"connectionId": connection_id})
                logger.info(f"Successfully removed stale connection: {connection_id}")
            except Exception as cleanup_error:
                logger.error(
                    f"Error removing stale connection {connection_id}: {cleanup_error}"
                )
        else:
            logger.error(f"ClientError sending to connection {connection_id}: {e}")

        return False

    except Exception as e:
        logger.error(
            f"Unexpected error sending to connection {connection_id}: {e}",
            exc_info=True,
        )
        return False


def broadcast_notification(message: Dict[str, Any], exclude_user_id: str = None) -> int:
    """Broadcast notification to all connected users"""

    try:
        logger.info(f"Broadcasting notification (excluding user: {exclude_user_id})")

        # Get all connections
        scan_response = connections_table.scan()
        connections = scan_response.get("Items", [])

        logger.info(f"Found {len(connections)} total connections for broadcast")

        successful_sends = 0

        for connection in connections:
            # Skip excluded user if specified
            if exclude_user_id and connection.get("userId") == exclude_user_id:
                continue

            connection_id = connection["connectionId"]
            if send_message_to_connection(connection_id, message):
                successful_sends += 1

        logger.info(f"Broadcast completed - sent to {successful_sends} connections")
        return successful_sends

    except Exception as e:
        logger.error(f"Error broadcasting notification: {e}", exc_info=True)
        return 0


def send_admin_notification(admin_message: str, priority: str = "normal") -> int:
    """Send administrative notifications"""

    try:
        logger.info(f"Sending admin notification - Priority: {priority}")

        message = {
            "type": "admin_notification",
            "priority": priority,
            "message": admin_message,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        # Send to admin topic subscribers
        sent_count = send_notification_to_topic("admin.notifications", message)
        logger.info(f"Admin notification sent to {sent_count} recipients")
        return sent_count

    except Exception as e:
        logger.error(f"Error sending admin notification: {e}", exc_info=True)
        return 0


def send_system_status(status: str, details: Dict[str, Any] = None) -> int:
    """Send system status updates"""

    try:
        logger.info(f"Sending system status update - Status: {status}")

        message = {
            "type": "system_status",
            "status": status,
            "details": details or {},
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        # Send to system status subscribers
        sent_count = send_notification_to_topic("system.status", message)
        logger.info(f"System status sent to {sent_count} recipients")
        return sent_count

    except Exception as e:
        logger.error(f"Error sending system status: {e}", exc_info=True)
        return 0
