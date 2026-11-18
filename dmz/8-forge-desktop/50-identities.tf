# The users who may sign in. Entra Connect syncs this group from AD in a customer installation; in this tenant it is a
# cloud group with the approved test user. Agent Forge never writes to it.
data "azuread_user" "desktop" {
  for_each = var.desktop_users

  user_principal_name = each.value
}

resource "azuread_group" "desktop_users" {
  display_name     = "DevDesktop-Users"
  description      = "Users who may sign in to the developer desktops Agent Forge assigns to them."
  security_enabled = true
  owners           = [data.azurerm_client_config.current.object_id]
}

resource "azuread_group_member" "desktop_users" {
  for_each = data.azuread_user.desktop

  group_object_id  = azuread_group.desktop_users.object_id
  member_object_id = each.value.object_id
}

# Agent Forge's identity, without a secret or certificate: Entra trusts the service-account tokens of eks-demo instead
# (federated credential).
resource "azuread_application" "forge" {
  display_name = "agent-forge-desktop"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "forge" {
  client_id = azuread_application.forge.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "forge" {
  application_id = azuread_application.forge.id
  display_name   = "eks-demo-agent-forge"
  description    = "Agent Forge on eks-demo"
  audiences      = [local.audience]
  issuer         = var.oidc_issuer
  subject        = var.forge_subject
}

# Azure Virtual Desktop's first-party service principal. It starts and deallocates the desktops.
data "azuread_service_principal" "avd" {
  client_id = "9cdead84-a844-4324-93f2-b2e6bb768d07"
}
