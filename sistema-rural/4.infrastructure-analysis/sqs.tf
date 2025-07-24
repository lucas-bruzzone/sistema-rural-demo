# ===================================
# SQS DEAD LETTER QUEUE
# ===================================

resource "aws_sqs_queue" "property_analysis_dlq" {
  name = "${var.project_name}-property-analysis-dlq"

  message_retention_seconds = 1209600 # 14 days

  tags = {
    Name = "${var.project_name}-property-analysis-dlq"
    Type = "dead-letter-queue"
  }
}

# ===================================
# SQS MAIN QUEUE WITH DELAY
# ===================================

resource "aws_sqs_queue" "property_analysis_delay" {
  name                       = "${var.project_name}-property-analysis-delay"
  delay_seconds              = 120 # 2 minutes delay
  max_message_size           = 262144
  message_retention_seconds  = 1209600 # 14 days
  receive_wait_time_seconds  = 10      # Long polling
  visibility_timeout_seconds = 180     # 3 minutes visibility timeout

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.property_analysis_dlq.arn
    maxReceiveCount     = 3
  })

  tags = {
    Name = "${var.project_name}-property-analysis-delay"
    Type = "delay-queue"
  }
}

# ===================================
# SQS QUEUE POLICIES
# ===================================

resource "aws_sqs_queue_policy" "property_analysis_delay" {
  queue_url = aws_sqs_queue.property_analysis_delay.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEventBridgeToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.property_analysis_delay.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "property_analysis_dlq" {
  queue_url = aws_sqs_queue.property_analysis_dlq.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSQSToSendToDLQ"
        Effect = "Allow"
        Principal = {
          Service = "sqs.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.property_analysis_dlq.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sqs_queue.property_analysis_delay.arn
          }
        }
      }
    ]
  })
}

data "aws_caller_identity" "current" {}