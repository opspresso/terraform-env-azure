terraform {
  required_version = "1.17.1"

  backend "azurerm" {
    subscription_id      = "ce097188-9b76-44f9-8bbd-366ae73ade04"
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatece097188"
    container_name       = "tfstate"
    key                  = "dmz/agentops-login-dmz.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
  }
}

provider "azuread" {
  tenant_id = "b84c843a-4ece-4ef7-8788-372e1f232c0a"
}
