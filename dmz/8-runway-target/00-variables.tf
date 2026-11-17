variable "subscription_id" {
  description = "The subscription Azure subscription 1 of the tenant Clush. The provider works only in this subscription."
  type        = string
  default     = "ce097188-9b76-44f9-8bbd-366ae73ade04"
}

variable "location" {
  description = "The location of the target's resources and the apps Agent Runway deploys."
  type        = string
  default     = "koreacentral"
}

variable "oidc_issuer" {
  description = "The OIDC issuer of the cluster eks-demo, where Agent Runway and its delivery workflows run (terraform-env-demo demo/5-eks). Entra trusts its service-account tokens."
  type        = string
  default     = "https://oidc.eks.ap-northeast-2.amazonaws.com/id/285B033CBC9DD804F6A143C9D86B59F2"
}

variable "runway_subject" {
  description = "The service account of Agent Runway on eks-demo. It writes Variables to the Key Vault and reads the console's choices."
  type        = string
  default     = "system:serviceaccount:agent-runway:agent-runway"
}

variable "delivery_subject" {
  description = "The service account of the vmss deploy and remove steps on eks-demo (argocd-env-projects charts/delivery)."
  type        = string
  default     = "system:serviceaccount:app-delivery:delivery-target"
}

variable "address_space" {
  description = "The address space of the VNet the app instances run in."
  type        = string
  default     = "10.40.0.0/16"
}
