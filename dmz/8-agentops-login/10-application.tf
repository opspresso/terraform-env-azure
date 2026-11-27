data "azuread_client_config" "current" {}

resource "azuread_application" "console" {
  display_name     = "Axleon AgentOps"
  sign_in_audience = "AzureADMyOrg"
  owners           = var.owner_object_ids

  # Forge assigns personal Azure desktops using the signed tenant UPN.
  optional_claims {
    id_token {
      name = "upn"
    }
  }

  web {
    redirect_uris = [
      "${var.console_origin}/api/auth/callback",
      "${var.console_origin}/signed-out",
    ]
  }
}

resource "azuread_service_principal" "console" {
  client_id = azuread_application.console.client_id
  owners    = var.owner_object_ids
}
