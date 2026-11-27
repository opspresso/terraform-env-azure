variable "console_origin" {
  description = "Public HTTPS origin of the AgentOps installation that receives the sign-in callback."
  type        = string

  validation {
    condition = (
      can(regex("^https://([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]([a-z0-9-]*[a-z0-9])?(:[1-9][0-9]{0,4})?$", var.console_origin)) &&
      try(tonumber(split(":", trimprefix(var.console_origin, "https://"))[1]) <= 65535, true)
    )
    error_message = "Set the HTTPS origin of the console, with a valid port if needed, without a path, query or trailing slash."
  }
}

variable "owner_object_ids" {
  description = "Directory object IDs of the designated owners of the AgentOps app and enterprise application."
  type        = set(string)

  validation {
    condition = length(var.owner_object_ids) > 0 && alltrue([
      for id in var.owner_object_ids : can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", id))
    ])
    error_message = "Provide at least one Entra directory owner object ID."
  }
}
