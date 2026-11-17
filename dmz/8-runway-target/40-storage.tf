# The app bundles: one container runway-<project>-<environment> per app, created by its deploy workflow. An app's
# identity reads only its container. Access is Entra only. No lifecycle rule: new and repaired instances download the
# current bundle at any age; the deploy workflow deletes the bundles of earlier Deployments.
resource "azurerm_storage_account" "bundles" {
  name                            = "strunwaydmz${local.suffix}"
  location                        = var.location
  resource_group_name             = azurerm_resource_group.target.name
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  min_tls_version                 = "TLS1_2"
  shared_access_key_enabled       = false
  allow_nested_items_to_be_public = false
  default_to_oauth_authentication = true
  tags                            = local.tags
}
