locals {
  functions = {
    api = {
      handler = "reservation_service.api.handler.handler"
      timeout = 15
      queue   = null
    }
    payment = {
      handler = "reservation_service.workers.payment_handler.handler"
      timeout = 30
      queue   = "payment"
    }
    expiration = {
      handler = "reservation_service.workers.expiration_handler.handler"
      timeout = 30
      queue   = "expiration"
    }
    notification = {
      handler = "reservation_service.workers.notification_handler.handler"
      timeout = 30
      queue   = "notification"
    }
    analytics = {
      handler = "reservation_service.workers.analytics_handler.handler"
      timeout = 30
      queue   = "analytics"
    }
  }
}

# Um único pacote é construído para evitar builds concorrentes do mesmo source_path.
module "package" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  create_function = false
  runtime         = "python3.12"
  source_path = [{
    path       = var.application_path
    uv_install = true
    patterns = [
      "!^infra/.*",
      "!^tests/.*",
      "!^\\.github/.*",
      "!^build/.*",
      "!^builds/.*",
      "!^scripts/.*",
      "!^README\\.md$",
      "!^PLAN\\.md$",
      "!^\\.git/.*",
    ]
  }]
  build_in_docker = var.build_in_docker
  docker_file     = var.docker_file
  artifacts_dir   = var.artifacts_dir
  hash_extra      = "reservation-service-shared-package"
}

module "lambda" {
  for_each = local.functions

  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 8.0"

  function_name = "${var.project_name}-${var.environment}-${each.key}"
  description   = "${each.key} Lambda for the reservation service"
  handler       = each.value.handler
  runtime       = "python3.12"
  timeout       = each.value.timeout
  memory_size   = 256

  create_package         = false
  local_existing_package = module.package.local_filename
  create_role            = false
  lambda_role            = var.lambda_roles[each.key]

  cloudwatch_logs_retention_in_days = var.log_retention_days
  attach_cloudwatch_logs_policy     = false
  attach_tracing_policy             = false
  allowed_triggers                  = {}

  environment_variables = {
    ENVIRONMENT = var.environment
    TABLE_NAME  = var.table_name
    TOPIC_ARN   = var.topic_arn
  }

  tags = {
    Component = "compute"
  }
}

resource "aws_lambda_event_source_mapping" "sqs" {
  for_each = {
    for name, function in local.functions : name => function
    if function.queue != null
  }

  event_source_arn                   = var.queue_arns[each.value.queue]
  function_name                      = module.lambda[each.key].lambda_function_arn
  batch_size                         = 10
  enabled                            = true
  function_response_types            = ["ReportBatchItemFailures"]
  maximum_batching_window_in_seconds = 1
}
