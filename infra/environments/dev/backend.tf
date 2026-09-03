terraform {
  # O bucket é informado no terraform init via -backend-config.
  # Isso permite manter o nome globalmente único fora do código versionado.
  backend "s3" {
    key          = "reservation-service/dev/terraform.tfstate"
    use_lockfile = true
    encrypt      = true
  }
}
