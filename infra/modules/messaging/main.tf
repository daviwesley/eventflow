locals {
  queue_names = toset([
    "payment",
    "expiration",
    "notification",
    "analytics",
  ])
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_sns_topic" "events" {
  name = "${var.project_name}-${var.environment}-events"

  tags = {
    Component = "messaging"
  }
}

resource "aws_sqs_queue" "dlq" {
  for_each = local.queue_names

  name                      = "${var.project_name}-${var.environment}-${each.key}-dlq"
  message_retention_seconds = 1209600
  receive_wait_time_seconds = 20

  redrive_allow_policy = jsonencode({
    redrivePermission = "byQueue"
    sourceQueueArns = [
      "arn:${data.aws_partition.current.partition}:sqs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:${var.project_name}-${var.environment}-${each.key}"
    ]
  })

  tags = {
    Component = "messaging"
    QueueRole = "dead-letter"
  }
}

resource "aws_sqs_queue" "main" {
  for_each = local.queue_names

  name                       = "${var.project_name}-${var.environment}-${each.key}"
  visibility_timeout_seconds = 60
  message_retention_seconds  = 345600
  receive_wait_time_seconds  = 20

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq[each.key].arn
    maxReceiveCount     = 5
  })

  tags = {
    Component = "messaging"
    QueueRole = "source"
  }
}

data "aws_iam_policy_document" "queue_policy" {
  for_each = local.queue_names

  statement {
    sid    = "AllowEventsTopic"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["sns.amazonaws.com"]
    }

    actions   = ["sqs:SendMessage"]
    resources = [aws_sqs_queue.main[each.key].arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [aws_sns_topic.events.arn]
    }
  }
}

resource "aws_sqs_queue_policy" "main" {
  for_each  = local.queue_names
  queue_url = aws_sqs_queue.main[each.key].url
  policy    = data.aws_iam_policy_document.queue_policy[each.key].json
}

resource "aws_sns_topic_subscription" "queue" {
  for_each = local.queue_names

  topic_arn            = aws_sns_topic.events.arn
  protocol             = "sqs"
  endpoint             = aws_sqs_queue.main[each.key].arn
  raw_message_delivery = true
}
