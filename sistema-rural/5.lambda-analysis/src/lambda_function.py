import json
import boto3
import os
import logging
from datetime import datetime, timezone
from typing import Dict, Any
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
dynamodb = boto3.resource("dynamodb")
s3 = boto3.client("s3")
eventbridge = boto3.client("events")

# Environment variables
ANALYSIS_TABLE = os.environ["PROPERTY_ANALYSIS_TABLE"]
CACHE_BUCKET = os.environ["GEOSPATIAL_CACHE_BUCKET"]
EVENTBRIDGE_BUS = os.environ["EVENTBRIDGE_BUS_NAME"]


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """Process geospatial analysis for properties"""

    try:
        # Parse SQS messages
        for record in event.get("Records", []):
            message_body = json.loads(record["body"])

            # Extract property info from EventBridge message
            if "detail" in message_body:
                property_data = message_body["detail"]
                property_id = property_data.get("propertyId")
                coordinates = property_data.get("coordinates")

                if property_id and coordinates:
                    logger.info(f"Processing analysis for property: {property_id}")

                    # Update status to processing
                    update_analysis_status(property_id, "processing")

                    # Perform geospatial analysis
                    analysis_results = perform_geospatial_analysis(coordinates)

                    # Save results
                    save_analysis_results(property_id, analysis_results)

                    # Publish completion event
                    publish_analysis_complete(property_id)

                    logger.info(f"Analysis completed for property: {property_id}")

        return {"statusCode": 200, "body": "Analysis completed"}

    except Exception as e:
        logger.error(f"Error processing analysis: {str(e)}")
        return {"statusCode": 500, "body": str(e)}


def perform_geospatial_analysis(coordinates: list) -> Dict[str, Any]:
    """Perform geospatial analysis"""

    try:
        # Calculate basic metrics
        results = {
            "elevation": get_elevation_data(coordinates),
            "ndvi": get_vegetation_index(coordinates),
            "slope": calculate_slope(coordinates),
            "water_distance": find_nearest_water(coordinates),
            "weather": get_weather_data(coordinates),
        }

        return results

    except Exception as e:
        logger.error(f"Error in geospatial analysis: {str(e)}")
        return {"error": str(e)}


def get_elevation_data(coordinates: list) -> Dict[str, float]:
    """Get elevation data (mock)"""
    center_lat = sum(coord[1] for coord in coordinates[:-1]) / (len(coordinates) - 1)
    center_lon = sum(coord[0] for coord in coordinates[:-1]) / (len(coordinates) - 1)

    # Mock elevation data
    return {"avg_elevation": 850.5, "min_elevation": 820.0, "max_elevation": 890.0}


def get_vegetation_index(coordinates: list) -> Dict[str, float]:
    """Calculate NDVI (mock)"""
    return {
        "avg_ndvi": 0.65,
        "vegetation_coverage": 78.5,
        "classification": "moderate_vegetation",
    }


def calculate_slope(coordinates: list) -> Dict[str, float]:
    """Calculate terrain slope (mock)"""
    return {"avg_slope": 5.2, "max_slope": 15.8, "slope_classification": "gentle"}


def find_nearest_water(coordinates: list) -> float:
    """Find distance to nearest water body (mock)"""
    return 450.0  # meters


def get_weather_data(coordinates: list) -> Dict[str, Any]:
    """Get weather/climate data (mock)"""
    return {
        "annual_rainfall": 1250.0,
        "avg_temperature": 22.5,
        "climate_zone": "tropical_highland",
    }


def update_analysis_status(property_id: str, status: str):
    """Update analysis status in DynamoDB"""
    table = dynamodb.Table(ANALYSIS_TABLE)

    table.put_item(
        Item={
            "propertyId": property_id,
            "analysisStatus": status,
            "createdAt": datetime.now(timezone.utc).isoformat(),
            "updatedAt": datetime.now(timezone.utc).isoformat(),
        }
    )


def save_analysis_results(property_id: str, results: Dict[str, Any]):
    """Save analysis results to DynamoDB"""
    table = dynamodb.Table(ANALYSIS_TABLE)

    # Convert float values to Decimal for DynamoDB
    def convert_floats(obj):
        if isinstance(obj, float):
            return Decimal(str(obj))
        elif isinstance(obj, dict):
            return {k: convert_floats(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [convert_floats(v) for v in obj]
        return obj

    converted_results = convert_floats(results)

    table.update_item(
        Key={"propertyId": property_id},
        UpdateExpression="SET analysisStatus = :status, analysisResults = :results, completedAt = :completed",
        ExpressionAttributeValues={
            ":status": "completed",
            ":results": converted_results,
            ":completed": datetime.now(timezone.utc).isoformat(),
        },
    )


def publish_analysis_complete(property_id: str):
    """Publish analysis completion event"""
    eventbridge.put_events(
        Entries=[
            {
                "Source": "geospatial.analysis",
                "DetailType": "Analysis Completed",
                "Detail": json.dumps(
                    {
                        "propertyId": property_id,
                        "status": "completed",
                        "timestamp": datetime.now(timezone.utc).isoformat(),
                    }
                ),
                "EventBusName": EVENTBRIDGE_BUS,
            }
        ]
    )
