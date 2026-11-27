locals {
  # The same rule in every phase of every day: deallocate a desktop var.idle_minutes after its user disconnects or logs
  # off, start it when its user connects, and never start one on a schedule.
  phases = ["rampUp", "peak", "rampDown", "offPeak"]
  phase_start = {
    rampUp   = { hour = 0, minute = 0 }
    peak     = { hour = 6, minute = 0 }
    rampDown = { hour = 12, minute = 0 }
    offPeak  = { hour = 18, minute = 0 }
  }
  phase_rules = merge([
    for phase in local.phases : {
      "${phase}StartTime"                 = local.phase_start[phase]
      "${phase}StartVMOnConnect"          = "Enable"
      "${phase}ActionOnDisconnect"        = "Deallocate"
      "${phase}MinutesToWaitOnDisconnect" = var.idle_minutes
      "${phase}ActionOnLogoff"            = "Deallocate"
      "${phase}MinutesToWaitOnLogoff"     = var.idle_minutes
    }
  ]...)
}

# azurerm 5.14.0 creates only pooled scaling plans, so the personal plan and its schedule use azapi. Autoscale needs the
# AVD service principal's power role at subscription scope before the plan is assigned (60-roles.tf).
resource "azapi_resource" "scaling_plan" {
  type      = "Microsoft.DesktopVirtualization/scalingPlans@2024-04-03"
  name      = "vdscaling-forge-desktop-dmz"
  parent_id = azurerm_resource_group.base.id
  location  = var.location
  tags      = local.tags

  body = {
    properties = {
      friendlyName = "Dev Desktop"
      hostPoolType = "Personal"
      timeZone     = var.time_zone
      schedules    = []
      hostPoolReferences = [for pool in [azurerm_virtual_desktop_host_pool.this, azurerm_virtual_desktop_host_pool.axleon] : {
        hostPoolArmPath    = pool.id
        scalingPlanEnabled = true
      }]
    }
  }

  depends_on = [
    azurerm_role_assignment.avd_power_on,
    azurerm_role_assignment.avd_power_on_off,
  ]
}

resource "azapi_resource" "scaling_schedule" {
  type      = "Microsoft.DesktopVirtualization/scalingPlans/personalSchedules@2024-04-03"
  name      = "always"
  parent_id = azapi_resource.scaling_plan.id

  body = {
    properties = merge(local.phase_rules, {
      daysOfWeek           = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
      rampUpAutoStartHosts = "None"
    })
  }
}
