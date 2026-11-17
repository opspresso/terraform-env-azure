# Two Entra applications without a secret or certificate: Entra trusts the service-account tokens of eks-demo instead
# (federated credentials). The secrets one is Agent Runway's (Variables and the console's choices); the deploy one is the
# vmss workflows'.
resource "azuread_application" "secrets" {
  display_name = "agent-runway-target-secrets"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "secrets" {
  client_id = azuread_application.secrets.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "secrets" {
  application_id = azuread_application.secrets.id
  display_name   = "eks-demo-agent-runway"
  description    = "Agent Runway on eks-demo"
  audiences      = [local.audience]
  issuer         = var.oidc_issuer
  subject        = var.runway_subject
}

resource "azuread_application" "deploy" {
  display_name = "agent-runway-target-deploy"
  owners       = [data.azurerm_client_config.current.object_id]
}

resource "azuread_service_principal" "deploy" {
  client_id = azuread_application.deploy.client_id
  owners    = [data.azurerm_client_config.current.object_id]
}

resource "azuread_application_federated_identity_credential" "deploy" {
  application_id = azuread_application.deploy.id
  display_name   = "eks-demo-delivery-target"
  description    = "The vmss deploy and remove steps on eks-demo"
  audiences      = [local.audience]
  issuer         = var.oidc_issuer
  subject        = var.delivery_subject
}
