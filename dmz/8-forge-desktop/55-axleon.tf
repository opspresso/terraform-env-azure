# Each Forge installation owns its VM group and host pool. The gallery and subnet serve both.
resource "azurerm_resource_group" "axleon_hosts" {
  name     = "rg-axleon-forge-desktops"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_desktop_host_pool" "axleon" {
  name                             = "vdpool-axleon-forge"
  resource_group_name              = azurerm_resource_group.base.name
  location                         = var.location
  friendly_name                    = "Axleon Developer Desktops"
  type                             = "Personal"
  personal_desktop_assignment_type = "Direct"
  load_balancer_type               = "Persistent"
  preferred_app_group_type         = "Desktop"
  start_vm_on_connect              = true
  validate_environment             = false
  custom_rdp_properties            = azurerm_virtual_desktop_host_pool.this.custom_rdp_properties
  tags                             = local.tags
}

resource "azurerm_virtual_desktop_application_group" "axleon" {
  name                         = "vdag-axleon-forge"
  resource_group_name          = azurerm_resource_group.base.name
  location                     = var.location
  host_pool_id                 = azurerm_virtual_desktop_host_pool.axleon.id
  type                         = "Desktop"
  friendly_name                = "Axleon Developer Desktop"
  default_desktop_display_name = "Axleon Developer Desktop"
  tags                         = local.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "axleon" {
  workspace_id         = azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.axleon.id
}

resource "azuread_application" "axleon_forge" {
  display_name = "Axleon Forge Desktops"
  owners       = azuread_application.forge.owners
}

resource "azuread_service_principal" "axleon_forge" {
  client_id = azuread_application.axleon_forge.client_id
  owners    = azuread_service_principal.forge.owners
}

resource "azuread_application_federated_identity_credential" "axleon_forge" {
  application_id = azuread_application.axleon_forge.id
  display_name   = "axleon-agent-forge"
  audiences      = [local.audience]
  issuer         = "https://oidc.eks.ap-northeast-2.amazonaws.com/id/EE3DC35B826323F1649AC9C588A2D43D"
  subject        = "system:serviceaccount:agent-forge:agent-forge"
}

locals {
  axleon_operators = {
    desktops  = { scope = azurerm_resource_group.axleon_hosts.id, actions = one(azurerm_role_definition.forge_desktops.permissions).actions }
    host_pool = { scope = azurerm_virtual_desktop_host_pool.axleon.id, actions = one(azurerm_role_definition.forge_host_pool.permissions).actions }
  }
}

resource "azurerm_role_definition" "axleon_operator" {
  for_each          = local.axleon_operators
  name              = "Axleon Forge ${each.key} operator"
  scope             = each.value.scope
  assignable_scopes = [each.value.scope]
  permissions { actions = each.value.actions }
}

resource "azurerm_role_assignment" "axleon_forge" {
  for_each = merge(azurerm_role_definition.axleon_operator, {
    subnet  = azurerm_role_definition.forge_subnet
    network = azurerm_role_definition.forge_network
    image   = azurerm_role_definition.forge_image
  })
  scope              = each.value.scope
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azuread_service_principal.axleon_forge.object_id
  principal_type     = "ServicePrincipal"
}

resource "azurerm_role_assignment" "axleon_desktop_users" {
  scope                = azurerm_virtual_desktop_application_group.axleon.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.desktop_users.object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "axleon_desktop_login" {
  scope                = azurerm_resource_group.axleon_hosts.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = azuread_group.desktop_users.object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "axleon_avd_start" {
  scope                = azurerm_resource_group.axleon_hosts.id
  role_definition_name = "Desktop Virtualization Power On Contributor"
  principal_id         = data.azuread_service_principal.avd.object_id
  principal_type       = "ServicePrincipal"
}
