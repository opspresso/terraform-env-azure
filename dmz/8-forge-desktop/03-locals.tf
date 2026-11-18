locals {
  tags = {
    Environment = "dmz"
    ManagedBy   = "Terraform"
    Project     = "terraform-env-azure/dmz/8-forge-desktop"
  }

  audience = "api://AzureADTokenExchange"
}
