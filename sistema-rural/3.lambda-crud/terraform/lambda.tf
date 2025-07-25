# sistema-rural/3.lambda-crud/terraform/lambda.tf

module "lambda_function" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.7"

  function_name = "${var.project_name}-properties-${var.environment}"
  source_path   = "../src"
  layers        = [module.lambda_layer.lambda_layer_arn]
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 512

  create_role = false
  lambda_role = aws_iam_role.lambda.arn

  environment_variables = {
    PROPERTIES_TABLE        = data.terraform_remote_state.infrastructure.outputs.properties_table_name
    PROPERTY_ANALYSIS_TABLE = data.terraform_remote_state.infrastructure.outputs.property_analysis_table_name
    EVENTBRIDGE_BUS_NAME    = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name
    ENVIRONMENT             = var.environment
  }

  depends_on = [module.lambda_layer]

  tags = {
    Name = "${var.project_name}-properties-lambda"
  }
}

module "lambda_layer" {
  source          = "terraform-aws-modules/lambda/aws"
  version         = "~> 4.7"
  create_function = false
  create_layer    = true

  layer_name          = "${var.project_name}-python-layer"
  description         = "Python dependencies for properties API"
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
    Name = "${var.project_name}-layer"
  }
}