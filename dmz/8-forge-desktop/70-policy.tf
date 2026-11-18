# Keeps every host pool of the base group personal with direct assignment. Agent Forge can write the host pool (to
# renew the registration token), so without this it could switch to automatic assignment and hand a desktop to another
# user. Agent Forge also checks both values before each create (host_pool_misconfigured).
resource "azurerm_policy_definition" "host_pool_assignment" {
  name         = "forge-desktop-host-pool-personal-direct"
  display_name = "Agent Forge desktops: host pools are personal with direct assignment"
  description  = "Denies an Azure Virtual Desktop host pool whose hostPoolType is not Personal or whose personalDesktopAssignmentType is not Direct."
  policy_type  = "Custom"
  mode         = "Indexed"

  metadata = jsonencode({ category = "Desktop Virtualization" })

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.DesktopVirtualization/hostPools" },
        {
          anyOf = [
            { field = "Microsoft.DesktopVirtualization/hostPools/hostPoolType", notEquals = "Personal" },
            { field = "Microsoft.DesktopVirtualization/hostPools/personalDesktopAssignmentType", notEquals = "Direct" },
          ]
        },
      ]
    }
    then = { effect = "deny" }
  })
}

resource "azurerm_resource_group_policy_assignment" "host_pool_assignment" {
  name                 = "forge-desktop-host-pool-personal-direct"
  display_name         = "Agent Forge desktops: host pools are personal with direct assignment"
  resource_group_id    = azurerm_resource_group.base.id
  policy_definition_id = azurerm_policy_definition.host_pool_assignment.id
  location             = var.location
}
