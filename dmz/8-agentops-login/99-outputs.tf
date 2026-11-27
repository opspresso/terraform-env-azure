output "entra_tenant_id" {
  description = "Value for ENTRA_TENANT_ID in AgentOps."
  value       = data.azuread_client_config.current.tenant_id
}

output "entra_client_id" {
  description = "Value for ENTRA_CLIENT_ID in AgentOps."
  value       = azuread_application.console.client_id
}
