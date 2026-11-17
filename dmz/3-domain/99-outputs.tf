output "domain" {
  value = azurerm_dns_zone.this.name
}

output "zone_id" {
  value = azurerm_dns_zone.this.id
}

output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "name_servers" {
  description = "The value of target_domains[\"<domain>\"] in terraform-env-opsp demo/8-app-delivery."
  value       = [for server in sort(tolist(azurerm_dns_zone.this.name_servers)) : trimsuffix(server, ".")]
}
