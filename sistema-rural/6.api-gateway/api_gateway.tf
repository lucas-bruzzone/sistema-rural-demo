# sistema-rural/6.api-gateway/api_gateway.tf

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

resource "aws_api_gateway_resource" "properties_import" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.properties.id
  path_part   = "import"
}

resource "aws_api_gateway_resource" "properties_report" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.properties.id
  path_part   = "report"
}

resource "aws_api_gateway_resource" "properties_id_analysis" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_resource.properties_id.id
  path_part   = "analysis"
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

# POST /properties/import
resource "aws_api_gateway_method" "properties_import_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_import.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# POST /properties/report
resource "aws_api_gateway_method" "properties_report_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_report.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

# GET /properties/{id}/analysis
resource "aws_api_gateway_method" "properties_id_analysis_get" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id_analysis.id
  http_method   = "GET"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id

  request_parameters = {
    "method.request.path.id" = true
  }
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

resource "aws_api_gateway_method" "properties_import_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_import.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "properties_report_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_report.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_method" "properties_id_analysis_options" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.properties_id_analysis.id
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

resource "aws_api_gateway_integration" "properties_import_post_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "properties_report_post_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_post.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn
}

resource "aws_api_gateway_integration" "properties_id_analysis_get_lambda" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_get.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = data.terraform_remote_state.lambda_crud.outputs.lambda_invoke_arn

  request_parameters = {
    "integration.request.path.id" = "method.request.path.id"
  }
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

resource "aws_api_gateway_integration" "properties_import_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "properties_report_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration" "properties_id_analysis_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_options.http_method
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

resource "aws_api_gateway_method_response" "properties_import_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "properties_report_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_post.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
}

resource "aws_api_gateway_method_response" "properties_id_analysis_get_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_get.http_method
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

resource "aws_api_gateway_method_response" "properties_import_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "properties_report_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_method_response" "properties_id_analysis_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_options.http_method
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

resource "aws_api_gateway_integration_response" "properties_import_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_post.http_method
  status_code = aws_api_gateway_method_response.properties_import_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_import_post_lambda]
}

resource "aws_api_gateway_integration_response" "properties_report_post_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_post.http_method
  status_code = aws_api_gateway_method_response.properties_report_post_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_report_post_lambda]
}

resource "aws_api_gateway_integration_response" "properties_id_analysis_get_200" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_get.http_method
  status_code = aws_api_gateway_method_response.properties_id_analysis_get_200.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }

  depends_on = [aws_api_gateway_integration.properties_id_analysis_get_lambda]
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
    "method.response.header.Access-Control-Allow-Methods" = "'GET,PUT,DELETE,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "properties_import_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_import.id
  http_method = aws_api_gateway_method.properties_import_options.http_method
  status_code = aws_api_gateway_method_response.properties_import_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "properties_report_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_report.id
  http_method = aws_api_gateway_method.properties_report_options.http_method
  status_code = aws_api_gateway_method_response.properties_report_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

resource "aws_api_gateway_integration_response" "properties_id_analysis_options" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  resource_id = aws_api_gateway_resource.properties_id_analysis.id
  http_method = aws_api_gateway_method.properties_id_analysis_options.http_method
  status_code = aws_api_gateway_method_response.properties_id_analysis_options.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
}

# ===================================
# DEPLOYMENT
# ===================================

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    aws_api_gateway_method.properties_get,
    aws_api_gateway_method.properties_post,
    aws_api_gateway_method.properties_import_post,
    aws_api_gateway_method.properties_report_post,
    aws_api_gateway_method.properties_id_analysis_get,
    aws_api_gateway_method.properties_id_put,
    aws_api_gateway_method.properties_id_delete,
    aws_api_gateway_method.properties_options,
    aws_api_gateway_method.properties_id_options,
    aws_api_gateway_method.properties_import_options,
    aws_api_gateway_method.properties_report_options,
    aws_api_gateway_method.properties_id_analysis_options,
    aws_api_gateway_integration.properties_get_lambda,
    aws_api_gateway_integration.properties_post_lambda,
    aws_api_gateway_integration.properties_import_post_lambda,
    aws_api_gateway_integration.properties_report_post_lambda,
    aws_api_gateway_integration.properties_id_analysis_get_lambda,
    aws_api_gateway_integration.properties_id_put_lambda,
    aws_api_gateway_integration.properties_id_delete_lambda,
    aws_api_gateway_integration.properties_options,
    aws_api_gateway_integration.properties_id_options,
    aws_api_gateway_integration.properties_import_options,
    aws_api_gateway_integration.properties_report_options,
    aws_api_gateway_integration.properties_id_analysis_options,
  ]

  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.properties.id,
      aws_api_gateway_resource.properties_id.id,
      aws_api_gateway_resource.properties_import.id,
      aws_api_gateway_resource.properties_report.id,
      aws_api_gateway_resource.properties_id_analysis.id,
      aws_api_gateway_method.properties_get.id,
      aws_api_gateway_method.properties_post.id,
      aws_api_gateway_method.properties_import_post.id,
      aws_api_gateway_method.properties_report_post.id,
      aws_api_gateway_method.properties_id_analysis_get.id,
      aws_api_gateway_method.properties_id_put.id,
      aws_api_gateway_method.properties_id_delete.id,
      aws_api_gateway_integration.properties_get_lambda.id,
      aws_api_gateway_integration.properties_post_lambda.id,
      aws_api_gateway_integration.properties_import_post_lambda.id,
      aws_api_gateway_integration.properties_report_post_lambda.id,
      aws_api_gateway_integration.properties_id_analysis_get_lambda.id,
      aws_api_gateway_integration.properties_id_put_lambda.id,
      aws_api_gateway_integration.properties_id_delete_lambda.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ===================================
# STAGE
# ===================================

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment

  xray_tracing_enabled = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      error          = "$context.error.message"
      errorType      = "$context.error.messageString"
    })
  }

  tags = {
    Name = "${var.project_name}-api-stage"
    Type = "api-stage"
  }
}

# ===================================
# CLOUDWATCH LOGS
# ===================================

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${var.project_name}-api"
  retention_in_days = 7

  tags = {
    Name = "${var.project_name}-api-logs"
    Type = "api-logs"
  }
}

# ===================================
# LAMBDA PERMISSION
# ===================================

resource "aws_lambda_permission" "api_gateway_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = data.terraform_remote_state.lambda_crud.outputs.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}