# ===================================
# IAM ROLE - EVENTBRIDGE
# ===================================

resource "aws_iam_role" "eventbridge_role" {
  name = "${var.project_name}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-eventbridge-role"
    Type = "service-role"
  }
}

resource "aws_iam_role_policy" "eventbridge_sqs_policy" {
  name = "${var.project_name}-eventbridge-sqs-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.property_analysis_delay.arn,
          aws_sqs_queue.property_analysis_dlq.arn
        ]
      }
    ]
  })
}

# ===================================
# IAM ROLE - LAMBDA ANALYSIS
# ===================================

resource "aws_iam_role" "lambda_analysis_role" {
  name = "${var.project_name}-lambda-analysis-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "${var.project_name}-lambda-analysis-role"
    Type = "lambda-execution-role"
  }
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda_analysis_role.name
}

resource "aws_iam_role_policy" "lambda_analysis_policy" {
  name = "${var.project_name}-lambda-analysis-policy"
  role = aws_iam_role.lambda_analysis_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          # Tabela de análises
          data.terraform_remote_state.infrastructure.outputs.property_analysis_table_arn,
          "${data.terraform_remote_state.infrastructure.outputs.property_analysis_table_arn}/index/*",
          # ADICIONAR: Tabela principal de propriedades
          data.terraform_remote_state.infrastructure.outputs.properties_table_arn,
          "${data.terraform_remote_state.infrastructure.outputs.properties_table_arn}/index/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.geospatial_cache.arn,
          "${aws_s3_bucket.geospatial_cache.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.property_analysis_delay.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "events:PutEvents"
        ]
        Resource = [
          aws_cloudwatch_event_bus.property_analysis.arn
        ]
      }
    ]
  })
}

