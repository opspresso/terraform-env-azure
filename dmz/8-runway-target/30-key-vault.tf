# The Variables of the environment dmz. Agent Runway writes them (secret ar-<sha256 of the path>); an app's identity
# reads only the secrets its workflow assigned to it. A deleted secret is recovered when Agent Runway writes it again,
# so purge protection stays off and nothing is purged.
resource "azurerm_key_vault" "this" {
  name                       = "kv-runway-dmz-${local.suffix}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.target.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags
}
