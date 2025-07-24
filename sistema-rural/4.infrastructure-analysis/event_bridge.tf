# ===================================
# EVENTBRIDGE CUSTOM BUS
# ===================================

resource "aws_cloudwatch_event_bus" "property_analysis" {
  name = "${var.project_name}-property-analysis"

  tags = {
    Name = "${var.project_name}-property-analysis-bus"
    Type = "event-processing"
  }
}

# ===================================
# EVENTBRIDGE RULE - PROPERTY CREATED
# ===================================

resource "aws_cloudwatch_event_rule" "property_created" {
  name           = "${var.project_name}-property-created"
  description    = "Trigger analysis when property is created"
  event_bus_name = aws_cloudwatch_event_bus.property_analysis.name

  event_pattern = jsonencode({
    source      = ["property.service"]
    detail-type = ["Property Created"]
    detail = {
      status = ["created"]
    }
  })

  tags = {
    Name = "${var.project_name}-property-created-rule"
    Type = "event-rule"
  }
}

# ===================================
# EVENTBRIDGE TARGET - SQS WITH DELAY
# ===================================

resource "aws_cloudwatch_event_target" "property_analysis_sqs" {
  rule           = aws_cloudwatch_event_rule.property_created.name
  event_bus_name = aws_cloudwatch_event_bus.property_analysis.name
  target_id      = "PropertyAnalysisSQSTarget"
  arn            = aws_sqs_queue.property_analysis_delay.arn
}

# ===================================
# EVENTBRIDGE ARCHIVE
# ===================================

resource "aws_cloudwatch_event_archive" "property_analysis" {
  name             = "${var.project_name}-archive"
  event_source_arn = aws_cloudwatch_event_bus.property_analysis.arn
  description      = "Archive for property analysis events"
  retention_days   = 30

  event_pattern = jsonencode({
    source = ["property.service"]
  })
}