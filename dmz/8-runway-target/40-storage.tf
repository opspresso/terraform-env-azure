# The app bundles: one container runway-<project>-<environment> per app, created by its deploy workflow. An app's
# identity reads only its container. Access is Entra only.
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

resource "azurerm_storage_management_policy" "bundles" {
  storage_account_id = azurerm_storage_account.bundles.id

  rule {
    name    = "expire-bundles"
    enabled = true

    filters {
      blob_types = ["blockBlob"]
    }

    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 90
      }
    }
  }
}
