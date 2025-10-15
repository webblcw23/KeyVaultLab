variable "resource_group_name" {
  description = "The name of the Resource Group in which all resources are created"
  type        = string
  default = "KeyVaultLab-RG"
}

variable "location" {
  description = "The Azure region in which all resources are created"
  type        = string
  default     = "UK South"
}

variable "tenant_id" {
  description = "The Tenant ID of the Azure Active Directory"
  type        = string
    default     = "f0445b33-db6a-455d-8714-59168c138593"
}

variable "subscription_id" {
  description = "The Subscription ID in which all resources are created"
  type        = string
    default     = "91c0fe80-4528-4bf2-9796-5d0f2a250518"
}
