terraform {
  # Backend local durante o desenvolvimento inicial.
  # Deploys via GitHub Actions exigirão backend remoto persistente.
  backend "local" {
    path = "terraform.tfstate"
  }
}

