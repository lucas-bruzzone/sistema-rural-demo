module "lambda_geospatial" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 4.7"

  function_name = "${var.project_name}-geospatial-${var.environment}"
  source_path   = "../src"
  layers        = [module.lambda_geospatial_layer.lambda_layer_arn]
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 300 # 5 minutes
  memory_size   = 512

  create_role = false
  lambda_role = data.terraform_remote_state.analysis_infra.outputs.lambda_analysis_role_arn

  environment_variables = {
    PROPERTIES_TABLE        = data.terraform_remote_state.infrastructure.outputs.properties_table_name
    PROPERTY_ANALYSIS_TABLE = data.terraform_remote_state.infrastructure.outputs.property_analysis_table_name
    GEOSPATIAL_CACHE_BUCKET = data.terraform_remote_state.analysis_infra.outputs.geospatial_cache_bucket_name
    EVENTBRIDGE_BUS_NAME    = data.terraform_remote_state.analysis_infra.outputs.property_analysis_bus_name
    ENVIRONMENT             = var.environment
  }

  depends_on = [module.lambda_geospatial_layer]

  tags = {
    Name = "${var.project_name}-geospatial-lambda"
    Type = "geospatial-processing"
  }
}

module "lambda_geospatial_layer" {
  source          = "terraform-aws-modules/lambda/aws"
  version         = "~> 4.7"
  create_function = false
  create_layer    = true

  layer_name          = "${var.project_name}-geospatial-layer"
  description         = "Geospatial libraries layer (numpy, etc.)"
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
    Name = "${var.project_name}-geospatial-layer"
    Type = "geospatial-dependencies"
  }
}

# SQS Event Source Mapping
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = data.terraform_remote_state.analysis_infra.outputs.property_analysis_delay_queue_arn
  function_name    = module.lambda_geospatial.lambda_function_arn
  batch_size       = 1

  depends_on = [module.lambda_geospatial]
}