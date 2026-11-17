# The HTTPS entry of every app: a custom domain <host> with a managed certificate and a route to the app's load
# balancer. The deploy workflows add them to the profile's only endpoint.
resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-agent-runway-dmz"
  resource_group_name = azurerm_resource_group.target.name
  sku_name            = "Standard_AzureFrontDoor"
  tags                = local.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "runway" {
  name                     = "runway"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = local.tags
}
