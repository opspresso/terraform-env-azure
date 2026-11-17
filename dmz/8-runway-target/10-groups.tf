# The target's shared resources: the network, the Key Vault, the bundle storage and the Front Door profile.
resource "azurerm_resource_group" "target" {
  name     = "rg-agent-runway-dmz"
  location = var.location
  tags     = local.tags
}

# The apps: every resource the vmss workflows create, named runway-<project>-<environment>. The deploy identity is
# Contributor here and nowhere else.
resource "azurerm_resource_group" "apps" {
  name     = "rg-agent-runway-dmz-apps"
  location = var.location
  tags     = local.tags
}
