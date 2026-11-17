locals {
  tags = {
    Environment = "dmz"
    ManagedBy   = "Terraform"
    Project     = "terraform-env-azure/dmz/8-runway-target"
  }

  # Globally unique names derive from the subscription, so another subscription gets other names.
  suffix = substr(replace(var.subscription_id, "-", ""), 0, 8)

  domain   = data.terraform_remote_state.domain.outputs.domain
  zone_id  = data.terraform_remote_state.domain.outputs.zone_id
  audience = "api://AzureADTokenExchange"
}
