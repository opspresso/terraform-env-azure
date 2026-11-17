data "terraform_remote_state" "domain" {
  backend = "azurerm"

  config = {
    subscription_id      = "ce097188-9b76-44f9-8bbd-366ae73ade04"
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "tfstatece097188"
    container_name       = "tfstate"
    key                  = "dmz/domain-dmz.tfstate"
    use_azuread_auth     = true
  }
}
