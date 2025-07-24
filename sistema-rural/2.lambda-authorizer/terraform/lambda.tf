module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.7"

  function_name = "${var.project_name}-authorizer-${var.environment}"
  source_path   = "../src"
  layers        = [module.lambda_layer.lambda_layer_arn]
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  create_role = false
  lambda_role = aws_iam_role.lambda.arn

  environment_variables = {
    COGNITO_USER_POOL_ID = data.terraform_remote_state.infrastructure.outputs.cognito_user_pool_id
    COGNITO_REGION       = var.aws_region
  }

  depends_on = [module.lambda_layer]

  tags = {
    Name = "${var.project_name}-authorizer-lambda"
  }
}

module "lambda_layer" {
  source          = "terraform-aws-modules/lambda/aws"
  version         = "~> 4.7"
  create_function = false
  create_layer    = true

  layer_name          = "${var.project_name}-authorizer-layer"
  description         = "JWT validation dependencies for WebSocket authorizer"
  compatible_runtimes = ["python3.11"]
  runtime             = "python3.11"

  source_path = [
    {
      path             = "../src/lambda-layer"
      pip_requirements = true
      prefix_in_zip    = "python"
    }
  ]

  store_on_s3 = false

  tags = {
    Name = "${var.project_name}-authorizer-layer"
  }
}