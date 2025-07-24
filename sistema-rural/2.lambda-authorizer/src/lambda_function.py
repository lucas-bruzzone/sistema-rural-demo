import json
import jwt
import requests
import os
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

# Environment variables
COGNITO_USER_POOL_ID = os.environ["COGNITO_USER_POOL_ID"]
COGNITO_REGION = os.environ["COGNITO_REGION"]

# Cache for JWKS
jwks_cache = {}


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """WebSocket Authorizer Lambda"""

    try:
        logger.info(f"Authorizer event: {json.dumps(event)}")

        # Extract token from queryStringParameters or headers
        query_params = event.get("queryStringParameters") or {}
        headers = event.get("headers") or {}

        token = (
            query_params.get("token")
            or query_params.get("access_token")
            or headers.get("Authorization", "").replace("Bearer ", "")
            or headers.get("authorization", "").replace("Bearer ", "")
        )

        if not token:
            logger.error("No token provided")
            return generate_policy("user", "Deny", event["methodArn"])

        # Validate token
        user_info = validate_cognito_token(token)
        if not user_info:
            logger.error("Invalid token")
            return generate_policy("user", "Deny", event["methodArn"])

        logger.info(f"User authenticated: {user_info.get('username')}")

        # Generate allow policy with user context
        policy = generate_policy(
            user_info["username"], "Allow", event["methodArn"], user_info
        )

        return policy

    except Exception as e:
        logger.error(f"Authorizer error: {str(e)}", exc_info=True)
        return generate_policy("user", "Deny", event["methodArn"])


def validate_cognito_token(token: str) -> Dict[str, Any]:
    """Validate Cognito JWT token"""

    try:
        # Get JWKS if not cached
        if not jwks_cache:
            jwks_url = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_USER_POOL_ID}/.well-known/jwks.json"
            response = requests.get(jwks_url)
            jwks_cache.update(response.json())

        # Decode token header to get kid
        header = jwt.get_unverified_header(token)
        kid = header["kid"]

        # Find the key
        key = None
        for jwk in jwks_cache["keys"]:
            if jwk["kid"] == kid:
                key = jwt.algorithms.RSAAlgorithm.from_jwk(json.dumps(jwk))
                break

        if not key:
            logger.error("Key not found in JWKS")
            return None

        # Verify token
        payload = jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=None,  # Skip audience validation for access tokens
            options={"verify_aud": False},
        )

        # Validate token_use
        if payload.get("token_use") not in ["access", "id"]:
            logger.error(f"Invalid token_use: {payload.get('token_use')}")
            return None

        # Extract user info
        return {
            "username": payload.get("username") or payload.get("cognito:username"),
            "user_id": payload.get("sub"),
            "email": payload.get("email"),
            "token_use": payload.get("token_use"),
            "client_id": payload.get("client_id") or payload.get("aud"),
            "scope": payload.get("scope", "").split() if payload.get("scope") else [],
        }

    except jwt.ExpiredSignatureError:
        logger.error("Token expired")
        return None
    except jwt.InvalidTokenError as e:
        logger.error(f"Invalid token: {str(e)}")
        return None
    except Exception as e:
        logger.error(f"Token validation error: {str(e)}")
        return None


def generate_policy(
    principal_id: str, effect: str, resource: str, user_info: Dict[str, Any] = None
) -> Dict[str, Any]:
    """Generate IAM policy for API Gateway"""

    policy = {
        "principalId": principal_id,
        "policyDocument": {
            "Version": "2012-10-17",
            "Statement": [
                {"Action": "execute-api:Invoke", "Effect": effect, "Resource": resource}
            ],
        },
    }

    # Add user context if available
    if user_info and effect == "Allow":
        policy["context"] = {
            "userId": user_info.get("user_id", ""),
            "username": user_info.get("username", ""),
            "email": user_info.get("email", ""),
            "tokenUse": user_info.get("token_use", ""),
            "clientId": user_info.get("client_id", ""),
        }

    return policy
