resource "aws_cloudwatch_metric_alarm" "dlq_messages" {
  for_each = var.dlq_arns

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-dlq-not-empty"
  alarm_description   = "Indica mensagens aguardando análise na DLQ ${each.key}."
  namespace           = "AWS/SQS"
  metric_name         = "ApproximateNumberOfMessagesVisible"
  dimensions          = { QueueName = "${var.project_name}-${var.environment}-${each.key}-dlq" }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"

  tags = {
    Component = "observability"
  }
}
