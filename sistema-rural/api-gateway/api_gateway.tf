# ===================================
# API GATEWAY REST API
# ===================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "API Gateway for ${var.project_name}"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# ===================================
# COGNITO AUTHORIZER
# ===================================

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "${var.project_name}-cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.main.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [data.terraform_remote_state.infrastructure.outputs.cognito_user_pool_arn]
}

# ===================================
# RESOURCES
# ===================================

resource "aws_api_gateway_resource" "properties" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "properties"
}

resource "aws_api_gateway_resource" "properties_id" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.properties.id
  path_part   = "{id}"
}

# ===================================
# METHODS
# ===================================

# GET /properties
resource "aws_api_gateway_method" "properties_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# POST /properties
resource "aws_api_gateway_method" "properties_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# PUT /properties/{id}
resource "aws_api_gateway_method" "properties_id_put" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "PUT"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

# DELETE /properties/{id}
resource "aws_api_gateway_method" "properties_id_delete" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
}

# OPTIONS for CORS
resource "aws_api_gateway_method" "properties_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "properties_id_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

# ===================================
# INTEGRATIONS
# ===================================

resource "aws_api_gateway_integration" "properties_get_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "properties_post_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "properties_id_put_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_put.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

resource "aws_api_gateway_integration" "properties_id_delete_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_delete.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
}

# CORS Integrations
resource "aws_api_gateway_integration" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

# ===================================
# METHOD RESPONSES
# ===================================

resource "aws_api_gateway_method_response" "properties_get_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_get.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "properties_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "properties_id_put_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_put.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "properties_id_delete_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_delete.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

# CORS Method Responses
resource "aws_api_gateway_method_response" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

# ===================================
# INTEGRATION RESPONSES
# ===================================

resource "aws_api_gateway_integration_response" "properties_get_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_get.http_method
  status_code = aws_api_gateway_method_response.properties_get_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_get_lambda]
}

resource "aws_api_gateway_integration_response" "properties_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_post.http_method
  status_code = aws_api_gateway_method_response.properties_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_post_lambda]
}

resource "aws_api_gateway_integration_response" "properties_id_put_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_put.http_method
  status_code = aws_api_gateway_method_response.properties_id_put_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_id_put_lambda]
}

resource "aws_api_gateway_integration_response" "properties_id_delete_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_delete.http_method
  status_code = aws_api_gateway_method_response.properties_id_delete_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_id_delete_lambda]
}

# CORS Integration Responses
resource "aws_api_gateway_integration_response" "properties_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties.id
  http_method = aws_api_gateway_method.properties_options.http_method
  status_code = aws_api_gateway_method_response.properties_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "properties_id_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id.id
  http_method = aws_api_gateway_method.properties_id_options.http_method
  status_code = aws_api_gateway_method_response.properties_id_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}