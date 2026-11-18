# The shared resources: the network, the AVD workspace, host pool, app group and scaling plan, and the gallery.
resource "azurerm_resource_group" "base" {
  name     = "rg-forge-desktop-dmz"
  location = var.location
  tags     = local.tags
}

# The desktops: the VM, NIC, disks and extensions of every desktop, created and removed by Agent Forge through ARM
# deployments. Terraform manages none of them. Agent Forge has write access here and nowhere else.
resource "azurerm_resource_group" "desktops" {
  name     = "rg-forge-desktop-dmz-hosts"
  location = var.location
  tags     = local.tags
}
