# Minimal Terraform root module. The full AKS design is opt-in.
# To review it: cp terraform/aks-design.tf.example terraform/aks-design.tf
terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
  }
}
