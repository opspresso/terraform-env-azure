# The users of DevDesktop-Users: see the desktop of the app group (AVD shows each user only the desktop assigned to them)
# and sign in to Entra joined VMs as a standard user.
resource "azurerm_role_assignment" "users_app_group" {
  scope                = azurerm_virtual_desktop_application_group.desktop.id
  role_definition_name = "Desktop Virtualization User"
  principal_id         = azuread_group.desktop_users.object_id
  principal_type       = "Group"
}

resource "azurerm_role_assignment" "users_login" {
  scope                = azurerm_resource_group.desktops.id
  role_definition_name = "Virtual Machine User Login"
  principal_id         = azuread_group.desktop_users.object_id
  principal_type       = "Group"
}

# Azure Virtual Desktop: Start VM on Connect needs the power-on role where the VMs are; a personal scaling plan needs
# the power-on-off role at subscription scope, or autoscale does not work (Microsoft Learn, "Create and assign an
# autoscale scaling plan").
resource "azurerm_role_assignment" "avd_power_on" {
  scope                = azurerm_resource_group.desktops.id
  role_definition_name = "Desktop Virtualization Power On Contributor"
  principal_id         = data.azuread_service_principal.avd.object_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "avd_power_on_off" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Desktop Virtualization Power On Off Contributor"
  principal_id         = data.azuread_service_principal.avd.object_id
  principal_type       = "ServicePrincipal"
}

# Agent Forge: custom roles with exactly the calls of its Azure provider, instead of Virtual Machine Contributor and
# Desktop Virtualization Host Pool Contributor, which also grant storage keys, backup vaults and deleting the host pool.
# No Key Vault access and no write outside the desktops group.
# The calls of Agent Forge's desktop template and power actions (agent-forge Azure provider). The template creates the
# NIC, the VM (its OS disk implicitly, which needs disks/write), the AADLoginForWindows extension and a run command
# that installs the AVD agent with the registration token as a protected parameter.
resource "azurerm_role_definition" "forge_desktops" {
  name        = "Agent Forge desktop operator (dmz)"
  scope       = azurerm_resource_group.desktops.id
  description = "Creates, powers and deletes the desktop VMs, disks, NICs, extensions and run commands through ARM deployments."

  permissions {
    actions = [
      "Microsoft.Resources/subscriptions/resourceGroups/read",
      "Microsoft.Resources/deployments/read",
      "Microsoft.Resources/deployments/write",
      "Microsoft.Resources/deployments/operations/read",
      "Microsoft.Resources/deployments/operationstatuses/read",
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/write",
      "Microsoft.Compute/virtualMachines/delete",
      "Microsoft.Compute/virtualMachines/start/action",
      "Microsoft.Compute/virtualMachines/deallocate/action",
      "Microsoft.Compute/virtualMachines/instanceView/read",
      "Microsoft.Compute/virtualMachines/extensions/read",
      "Microsoft.Compute/virtualMachines/extensions/write",
      "Microsoft.Compute/virtualMachines/runCommands/read",
      "Microsoft.Compute/virtualMachines/runCommands/write",
      "Microsoft.Compute/disks/read",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/delete",
      "Microsoft.Network/networkInterfaces/read",
      "Microsoft.Network/networkInterfaces/write",
      "Microsoft.Network/networkInterfaces/delete",
      "Microsoft.Network/networkInterfaces/join/action",
    ]
  }

  assignable_scopes = [azurerm_resource_group.desktops.id]
}

resource "azurerm_role_definition" "forge_subnet" {
  name        = "Agent Forge subnet joiner (dmz)"
  scope       = azurerm_subnet.desktops.id
  description = "Attaches the desktop NICs to the desktops subnet."

  permissions {
    actions = [
      "Microsoft.Network/virtualNetworks/subnets/read",
      "Microsoft.Network/virtualNetworks/subnets/join/action",
    ]
  }

  assignable_scopes = [azurerm_subnet.desktops.id]
}

# hostpools/write is needed to renew the registration token. It could also change the assignment type; the Azure Policy
# in 70-policy.tf denies that. The role cannot delete the host pool.
resource "azurerm_role_definition" "forge_host_pool" {
  name        = "Agent Forge host pool operator (dmz)"
  scope       = azurerm_virtual_desktop_host_pool.this.id
  description = "Renews the registration token, assigns and removes session hosts, and logs off user sessions."

  permissions {
    actions = [
      "Microsoft.DesktopVirtualization/hostpools/read",
      "Microsoft.DesktopVirtualization/hostpools/write",
      "Microsoft.DesktopVirtualization/hostpools/retrieveRegistrationToken/action",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/write",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/delete",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/read",
      "Microsoft.DesktopVirtualization/hostpools/sessionhosts/usersessions/delete",
    ]
  }

  assignable_scopes = [azurerm_virtual_desktop_host_pool.this.id]
}

# The Forge console lists the subnets a pool can use from the VNet's properties (Azure Resource Graph), which needs
# read on the VNet itself; the subnet role above covers only the subnet.
resource "azurerm_role_definition" "forge_network" {
  name        = "Agent Forge network reader (dmz)"
  scope       = azurerm_virtual_network.this.id
  description = "Reads the desktops VNet so the Forge console can offer its subnets."

  permissions {
    actions = ["Microsoft.Network/virtualNetworks/read"]
  }

  assignable_scopes = [azurerm_virtual_network.this.id]
}

resource "azurerm_role_definition" "forge_image" {
  name        = "Agent Forge image reader (dmz)"
  scope       = azurerm_shared_image.win10.id
  description = "Reads the desktop image definition and its versions."

  permissions {
    actions = [
      "Microsoft.Compute/galleries/images/read",
      "Microsoft.Compute/galleries/images/versions/read",
    ]
  }

  assignable_scopes = [azurerm_shared_image.win10.id]
}

resource "azurerm_role_assignment" "forge" {
  for_each = {
    desktops  = azurerm_role_definition.forge_desktops
    subnet    = azurerm_role_definition.forge_subnet
    network   = azurerm_role_definition.forge_network
    host_pool = azurerm_role_definition.forge_host_pool
    image     = azurerm_role_definition.forge_image
  }

  scope              = each.value.scope
  role_definition_id = each.value.role_definition_resource_id
  principal_id       = azuread_service_principal.forge.object_id
  principal_type     = "ServicePrincipal"
}
