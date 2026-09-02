locals {
  lambda_names = toset([
    "api",
    "payment",
    "expiration",
    "notification",
    "analytics",
  ])
}

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

resource "aws_iam_role_policy_attachment" "logs" {
  for_each = local.lambda_names

  role       = aws_iam_role.lambda[each.key].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda" {
  for_each = local.lambda_names

  statement {
    sid       = "DynamoDbAccess"
    actions   = ["dynamodb:ConditionCheckItem", "dynamodb:DeleteItem", "dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:Query", "dynamodb:TransactWriteItems", "dynamodb:UpdateItem"]
    resources = [var.table_arn, "${var.table_arn}/index/*"]
  }

  statement {
    sid       = "PublishEvents"
    actions   = ["sns:Publish"]
    resources = [var.topic_arn]
  }

  dynamic "statement" {
    for_each = contains(["payment", "expiration", "notification", "analytics"], each.key) ? [1] : []

    content {
      sid       = "ConsumeOwnQueue"
      actions   = ["sqs:ChangeMessageVisibility", "sqs:DeleteMessage", "sqs:GetQueueAttributes", "sqs:ReceiveMessage"]
      resources = [var.consumer_queue_arns[each.key]]
    }
  }
}

resource "aws_iam_role_policy" "lambda" {
  for_each = local.lambda_names

  name   = "${var.project_name}-${var.environment}-${each.key}-policy"
  role   = aws_iam_role.lambda[each.key].id
  policy = data.aws_iam_policy_document.lambda[each.key].json
}
