# What an administrator enters in the Agent Forge desktop pool. No secret value.
output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  value = data.azurerm_subscription.current.subscription_id
}

output "location" {
  value = var.location
}

output "forge_client_id" {
  value = azuread_application.forge.client_id
}

output "desktop_resource_group" {
  value = azurerm_resource_group.desktops.name
}

output "subnet_id" {
  value = azurerm_subnet.desktops.id
}

output "host_pool_id" {
  value = azurerm_virtual_desktop_host_pool.this.id
}

output "app_group_id" {
  value = azurerm_virtual_desktop_application_group.desktop.id
}

output "workspace_id" {
  value = azurerm_virtual_desktop_workspace.this.id
}

output "gallery_image_definition_id" {
  value = azurerm_shared_image.win10.id
}

# Built from the name, not read from the gallery, so the first apply works before the image is published.
output "gallery_image_version_id" {
  value = "${azurerm_shared_image.win10.id}/versions/${var.image_version}"
}

# The image definition accepts trusted launch VMs only; Agent Forge creates trusted launch VMs.
output "trusted_launch" {
  value = azurerm_shared_image.win10.trusted_launch_enabled
}

output "egress_ip" {
  value = azurerm_public_ip.egress.ip_address
}
