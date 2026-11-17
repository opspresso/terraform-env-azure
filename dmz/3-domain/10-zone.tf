resource "azurerm_resource_group" "this" {
  name     = "rg-dns-dmz"
  location = var.location
  tags     = local.tags
}

# The zone of the domain. Its parent zone rovr.dev in AWS account opspresso delegates it with these name servers
# (terraform-env-opsp demo/8-app-delivery target_domains), so a new zone needs a new delegation: the zone is kept from destruction.
resource "azurerm_dns_zone" "this" {
  name                = var.domain
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  lifecycle {
    prevent_destroy = true
  }
}
