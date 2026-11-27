mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      tenant_id = "00000000-0000-4000-8000-000000000001"
      object_id = "00000000-0000-4000-8000-000000000002"
    }
  }
}

variables {
  owner_object_ids = ["00000000-0000-4000-8000-000000000003"]
}

run "single_tenant_web_client" {
  command = plan

  variables {
    console_origin = "https://pilot.example.test:8443"
  }

  assert {
    condition     = azuread_application.console.sign_in_audience == "AzureADMyOrg"
    error_message = "The console must use a single tenant."
  }

  assert {
    condition     = azuread_application.console.owners == var.owner_object_ids && azuread_service_principal.console.owners == var.owner_object_ids
    error_message = "Changing the Terraform caller must not transfer ownership."
  }

  assert {
    condition = toset(azuread_application.console.web[0].redirect_uris) == toset([
      "https://pilot.example.test:8443/api/auth/callback",
      "https://pilot.example.test:8443/signed-out",
    ])
    error_message = "The app registration must match the AgentOps sign-in and sign-out routes."
  }
}

run "reject_path_in_origin" {
  command = plan

  variables {
    console_origin = "https://pilot.example.test/studio"
  }

  expect_failures = [var.console_origin]
}

run "reject_invalid_port" {
  command = plan

  variables {
    console_origin = "https://pilot.example.test:65536"
  }

  expect_failures = [var.console_origin]
}
