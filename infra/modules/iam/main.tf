locals {
  lambda_names = toset([
    "api",
    "payment",
    "expiration",
    "notification",
    "analytics",
  ])

  lambda_permissions = {
    api = {
      dynamodb_actions = [
        "dynamodb:ConditionCheckItem",
        "dynamodb:DeleteItem",
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:Query",
        "dynamodb:TransactWriteItems",
        "dynamodb:UpdateItem",
      ]
      publishes_events = true
      queue            = null
    }
    payment = {
      dynamodb_actions = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"]
      publishes_events = true
      queue            = "payment"
    }
    expiration = {
      dynamodb_actions = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      publishes_events = true
      queue            = "expiration"
    }
    notification = {
      dynamodb_actions = []
      publishes_events = false
      queue            = "notification"
    }
    analytics = {
      dynamodb_actions = ["dynamodb:GetItem", "dynamodb:Query"]
      publishes_events = false
      queue            = "analytics"
    }
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "lambda" {
  for_each = local.lambda_names

  name = "${var.project_name}-${var.environment}-${each.key}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = {
    Component = "iam"
  }
}

data "aws_iam_policy_document" "lambda" {
  for_each = local.lambda_names

  dynamic "statement" {
    for_each = length(local.lambda_permissions[each.key].dynamodb_actions) > 0 ? [1] : []

    content {
      sid       = "DynamoDbAccess"
      actions   = local.lambda_permissions[each.key].dynamodb_actions
      resources = [var.table_arn, "${var.table_arn}/index/*"]
    }
  }

  dynamic "statement" {
    for_each = local.lambda_permissions[each.key].publishes_events ? [1] : []

    content {
      sid       = "PublishEvents"
      actions   = ["sns:Publish"]
      resources = [var.topic_arn]
    }
  }

  dynamic "statement" {
    for_each = local.lambda_permissions[each.key].queue != null ? [1] : []

    content {
      sid       = "ConsumeOwnQueue"
      actions   = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
      resources = [var.consumer_queue_arns[local.lambda_permissions[each.key].queue]]
    }
  }

  statement {
    sid       = "WriteLogs"
    actions   = ["logs:CreateLogGroup"]
    resources = ["*"]
  }

  statement {
    sid     = "WriteOwnLogStreams"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.project_name}-${var.environment}-${each.key}:*"
    ]
  }

}

resource "aws_iam_role_policy" "lambda" {
  for_each = local.lambda_names

  name   = "${var.project_name}-${var.environment}-${each.key}-policy"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.lambda[each.key].json
}
