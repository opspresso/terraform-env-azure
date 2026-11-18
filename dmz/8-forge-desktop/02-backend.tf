terraform {
  required_version = "1.17.1"

  backend "azurerm" {
    subscription_id      = "ce097188-9b76-44f9-8bbd-366ae73ade04"
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatece097188"
    container_name       = "tfstate"
    key                  = "dmz/forge-desktop-dmz.tfstate"
    use_azuread_auth     = true
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "5.14.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.10.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "2.14.0"
    }
    msgraph = {
      source  = "microsoft/msgraph"
      version = "0.6.0"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}

provider "azuread" {}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "msgraph" {}
