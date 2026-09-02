
output "topic_arn" {
  description = "ARN do tópico de eventos."
  value       = aws_sns_topic.events.arn
}

output "queue_arns" {
  description = "ARNs das filas principais por consumidor."
  value       = { for name, queue in aws_sqs_queue.main : name => queue.arn }
}

output "queue_urls" {
  description = "URLs das filas principais por consumidor."
  value       = { for name, queue in aws_sqs_queue.main : name => queue.url }
}

output "dlq_arns" {
  description = "ARNs das DLQs por consumidor."
  value       = { for name, queue in aws_sqs_queue.dlq : name => queue.arn }
}
