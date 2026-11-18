resource "azurerm_virtual_desktop_workspace" "this" {
  name                = "vdws-forge-desktop-dmz"
  location            = var.location
  resource_group_name = azurerm_resource_group.base.name
  friendly_name       = "Dev Desktop"
  tags                = local.tags
}

# One VM per user. Agent Forge registers each desktop with the host pool and assigns it to its owner's UPN (direct
# assignment). The Azure Policy in 70-policy.tf keeps the type and the assignment type. The RDP properties are those of
# Entra joined session hosts with Entra authentication (single sign-on). Agent Forge renews the registration token, so
# Terraform manages none.
resource "azurerm_virtual_desktop_host_pool" "this" {
  name                             = "vdpool-forge-desktop-dmz"
  location                         = var.location
  resource_group_name              = azurerm_resource_group.base.name
  friendly_name                    = "Dev Desktop"
  type                             = "Personal"
  personal_desktop_assignment_type = "Direct"
  load_balancer_type               = "Persistent"
  preferred_app_group_type         = "Desktop"
  start_vm_on_connect              = true
  validate_environment             = false
  custom_rdp_properties            = "targetisaadjoined:i:1;enablerdsaadauth:i:1;"
  tags                             = local.tags
}

resource "azurerm_virtual_desktop_application_group" "desktop" {
  name                         = "vdag-forge-desktop-dmz"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.base.name
  host_pool_id                 = azurerm_virtual_desktop_host_pool.this.id
  type                         = "Desktop"
  friendly_name                = "Dev Desktop"
  default_desktop_display_name = "Dev Desktop"
  tags                         = local.tags
}

resource "azurerm_virtual_desktop_workspace_application_group_association" "desktop" {
  workspace_id         = azurerm_virtual_desktop_workspace.this.id
  application_group_id = azurerm_virtual_desktop_application_group.desktop.id
}
