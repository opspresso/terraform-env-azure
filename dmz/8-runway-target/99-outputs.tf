# What an administrator enters in Agent Runway: the account and the vmss target of the environment dmz. No secret value.
output "account" {
  value = {
    name            = "clush-azure"
    cloud           = "azure"
    id              = data.azurerm_subscription.current.subscription_id
    region          = var.location
    tenantId        = data.azurerm_client_config.current.tenant_id
    access          = { clientId = azuread_application.secrets.client_id }
    keyVault        = azurerm_key_vault.this.name
    artifactStorage = azurerm_storage_account.bundles.name
    deployClientId  = azuread_application.deploy.client_id
  }
}

output "vmss_target" {
  value = {
    type               = "vmss"
    architectures      = ["amd64"]
    domain             = local.domain
    resourceGroup      = azurerm_resource_group.apps.name
    subnetId           = azurerm_subnet.apps.id
    dnsZoneId          = local.zone_id
    frontDoorProfileId = azurerm_cdn_frontdoor_profile.this.id
    platforms          = { "jar-21" = "temurin-21-jre", "jar-25" = "temurin-25-jre" }
  }
}

output "front_door_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.runway.host_name
}
