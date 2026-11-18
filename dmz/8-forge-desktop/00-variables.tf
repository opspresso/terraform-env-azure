variable "subscription_id" {
  description = "The subscription Azure subscription 1 of the tenant Clush. The provider works only in this subscription."
  type        = string
  default     = "ce097188-9b76-44f9-8bbd-366ae73ade04"
}

variable "location" {
  description = "The location of the desktops and their shared resources."
  type        = string
  default     = "koreacentral"
}

variable "time_zone" {
  description = "The Windows time zone of the scaling plan schedule."
  type        = string
  default     = "Korea Standard Time"
}

variable "oidc_issuer" {
  description = "The OIDC issuer of the cluster eks-demo, where Agent Forge runs (terraform-env-demo demo/5-eks). Entra trusts its service-account tokens."
  type        = string
  default     = "https://oidc.eks.ap-northeast-2.amazonaws.com/id/285B033CBC9DD804F6A143C9D86B59F2"
}

variable "forge_subject" {
  description = "The service account of Agent Forge on eks-demo. It creates, assigns, powers and removes the desktops."
  type        = string
  default     = "system:serviceaccount:agent-forge:agent-forge"
}

variable "address_space" {
  description = "The address space of the VNet the desktops run in."
  type        = string
  default     = "10.41.0.0/16"
}

variable "desktop_users" {
  description = "The UPNs of the members of the group DevDesktop-Users, who may sign in to the desktops Agent Forge assigns to them. A customer installation uses its own AD group synced by Entra Connect instead."
  type        = set(string)
  default     = ["jyyu@clush.ai"]
}

variable "idle_minutes" {
  description = "Minutes after a user disconnects or logs off before the scaling plan deallocates the desktop."
  type        = number
  default     = 60
}

variable "image_version" {
  description = "The gallery image version of dev-desktop-win10 that Agent Forge creates desktops from. Publish it with images/dev-desktop-win10 first."
  type        = string
  default     = "1.0.0"
}
