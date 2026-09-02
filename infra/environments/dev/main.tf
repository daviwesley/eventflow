provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

locals {
  application_path = "../../../"
  docker_file      = "../../../infra/docker/lambda-build.Dockerfile"
  artifacts_dir    = "../../../builds/lambda/"

}

module "data" {
  source = "../../modules/data"

  project_name = var.project_name
  environment  = var.environment
}

module "messaging" {
  source = "../../modules/messaging"

  project_name = var.project_name
  environment  = var.environment
}

module "iam" {
  source = "../../modules/iam"

  project_name        = var.project_name
  environment         = var.environment
  table_arn           = module.data.table_arn
  topic_arn           = module.messaging.topic_arn
  consumer_queue_arns = module.messaging.queue_arns
}

module "compute" {
  source = "../../modules/compute"

  project_name = var.project_name
  environment  = var.environment
  application_path = local.application_path
  build_in_docker  = true
  docker_file      = local.docker_file
  artifacts_dir    = local.artifacts_dir
  lambda_roles = module.iam.lambda_role_arns
  queue_arns = module.messaging.queue_arns
  table_name = module.data.table_name
  topic_arn  = module.messaging.topic_arn
}

module "api" {
  source = "../../modules/api"

  project_name       = var.project_name
  environment        = var.environment
  lambda_function_name = module.compute.api_function_name
  lambda_function_arn  = module.compute.api_function_arn
  lambda_invoke_arn    = module.compute.api_invoke_arn
}

module "observability" {
  source = "../../modules/observability"

  project_name = var.project_name
  environment  = var.environment
  dlq_arns     = module.messaging.dlq_arns
}
