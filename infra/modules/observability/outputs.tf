
output "dlq_alarm_names" {
  description = "Nomes dos alarmes de DLQ."
  value       = { for name, alarm in aws_cloudwatch_metric_alarm.dlq_messages : name => alarm.alarm_name }
}
