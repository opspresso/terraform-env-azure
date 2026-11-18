# Microsoft Entra authentication for RDP, which the host pool's enablerdsaadauth:i:1 needs: users sign in to the
# Entra joined desktops from Windows App with their Entra account, MFA and Conditional Access. Microsoft Learn
# ("Configure single sign-on for Azure Virtual Desktop using Microsoft Entra ID") sets it on the service principal
# Windows Cloud Login only. It is a tenant-wide setting and needs the Entra role Application Administrator or Cloud
# Application Administrator. No target device groups: without them a user confirms a consent prompt on a new desktop
# (Entra remembers up to 15 hosts for 30 days); hiding it is optional.
data "azuread_service_principal" "windows_cloud_login" {
  client_id = "270efc09-cd0d-444b-a71f-39af4910ec45"
}

# A PATCH of an existing singleton: destroying this resource leaves the setting on.
resource "msgraph_update_resource" "rdp_sign_in" {
  url = "servicePrincipals/${data.azuread_service_principal.windows_cloud_login.object_id}/remoteDesktopSecurityConfiguration"
  body = {
    "@odata.type"                  = "#microsoft.graph.remoteDesktopSecurityConfiguration"
    isRemoteDesktopProtocolEnabled = true
  }
}
