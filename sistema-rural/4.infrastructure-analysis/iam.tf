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
          data.terraform_remote_state.infrastructure.outputs.property_analysis_table_arn,
          "${data.terraform_remote_state.infrastructure.outputs.property_analysis_table_arn}/index/*",
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