resource "azurerm_shared_image_gallery" "this" {
  name                = "galforgedesktopdmz"
  location            = var.location
  resource_group_name = azurerm_resource_group.base.name
  description         = "Images of the Agent Forge developer desktops."
  tags                = local.tags
}

# Versions are published by the Packer template images/dev-desktop-win10. The source image
# (MicrosoftWindowsDesktop:Windows-10:win10-22h2-ent-g2) supports trusted launch and the SCSI and NVMe disk controllers;
# Dsv6 sizes accept NVMe only. Packer builds on a trusted launch VM, and a version captured from one publishes only
# into a TrustedLaunch definition (a TrustedLaunchSupported one refuses it), so every VM of this image is trusted launch.
resource "azurerm_shared_image" "win10" {
  name                                = "dev-desktop-win10"
  gallery_name                        = azurerm_shared_image_gallery.this.name
  location                            = var.location
  resource_group_name                 = azurerm_resource_group.base.name
  os_type                             = "Windows"
  specialized                         = false
  hyper_v_generation                  = "V2"
  architecture                        = "x64"
  trusted_launch_enabled              = true
  accelerated_network_support_enabled = true
  disk_controller_type_nvme_enabled   = true
  description                         = "Windows 10 Enterprise 22H2 single-session with Git, VS Code, Node.js, Python, Claude Code, Codex and opencode."
  tags                                = local.tags

  identifier {
    publisher = "opspresso"
    offer     = "dev-desktop"
    sku       = "win10-22h2-ent"
  }
}
