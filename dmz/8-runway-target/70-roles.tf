locals {
  # The only roles the deploy identity may assign, and only to the app identities it creates (service principals): read
  # one declared secret, read one bundle container.
  key_vault_secrets_user   = "4633458b-17de-408a-b874-0445c86b69e6"
  storage_blob_data_reader = "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1"
  assignable               = "${local.key_vault_secrets_user}, ${local.storage_blob_data_reader}"
  assign_condition         = <<-EOT
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
     )
     OR
     (
      @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable}}
      AND
      @Request[Microsoft.Authorization/roleAssignments:PrincipalType] ForAnyOfAnyValues:StringEqualsIgnoreCase {'ServicePrincipal'}
     )
    )
    AND
    (
     (
      !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
     )
     OR
     (
      @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.assignable}}
     )
    )
  EOT
}

# Agent Runway: writes, reads and deletes the Variables, and reads the subscription for the console's choices (VNets,
# subnets, DNS zones, Front Door profiles, resource groups).
resource "azurerm_role_assignment" "secrets_key_vault" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = azuread_service_principal.secrets.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "secrets_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.secrets.object_id
  principal_type       = "ServicePrincipal"
}

# The deploy workflows: everything of an app in the apps group; joining the apps subnet; the app's DNS records, Front
# Door route and custom domain; its bundle container; the names (not values) of the Variables; and assigning the two
# read roles above to the app's identity.
resource "azurerm_role_assignment" "deploy_apps" {
  scope                = azurerm_resource_group.apps.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_subnet" {
  scope                = azurerm_subnet.apps.id
  role_definition_name = "Network Contributor"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_zone" {
  scope                = local.zone_id
  role_definition_name = "DNS Zone Contributor"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_front_door" {
  scope                = azurerm_cdn_frontdoor_profile.this.id
  role_definition_name = "CDN Profile Contributor"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_definition" "bundle_writer" {
  name        = "Agent Runway bundle writer (dmz)"
  scope       = azurerm_storage_account.bundles.id
  description = "Creates and deletes the bundle containers of the vmss apps and writes their bundles."

  permissions {
    actions = [
      "Microsoft.Storage/storageAccounts/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
    ]
    data_actions = [
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
      "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action",
    ]
  }

  assignable_scopes = [azurerm_storage_account.bundles.id]
}

resource "azurerm_role_assignment" "deploy_bundles" {
  scope              = azurerm_storage_account.bundles.id
  role_definition_id = azurerm_role_definition.bundle_writer.role_definition_resource_id
  principal_id       = azuread_service_principal.deploy.object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_key_vault_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Reader"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "deploy_assign" {
  for_each = {
    key_vault = azurerm_key_vault.this.id
    bundles   = azurerm_storage_account.bundles.id
  }

  scope                = each.value
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azuread_service_principal.deploy.object_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = local.assign_condition
}
