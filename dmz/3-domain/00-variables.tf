variable "subscription_id" {
  description = "The subscription Azure subscription 1 of the tenant Clush. The provider works only in this subscription."
  type        = string
  default     = "ce097188-9b76-44f9-8bbd-366ae73ade04"
}

variable "location" {
  description = "The location of the resource group. Azure DNS zones are global."
  type        = string
  default     = "koreacentral"
}

variable "domain" {
  description = "The public zone of the Agent Runway environment dmz. The vmss target uses it as its app domain."
  type        = string
  default     = "dmz.rovr.dev"
}
