##############################################################################
# 02-prep – variables
##############################################################################

variable "namespace" {
  description = "Kubernetes namespace for the IDIG deployment."
  type        = string
}

variable "docker_registry" {
  description = "Target container registry URL."
  type        = string
}

variable "docker_user" {
  description = "Username for the target container registry."
  type        = string
}

variable "docker_password" {
  description = "Password / API key for the target container registry."
  type        = string
  sensitive   = true
}

variable "ibm_entitlement_key" {
  description = "IBM Entitlement Key for cp.icr.io/cp/datapower."
  type        = string
  sensitive   = true
}

variable "watsonx_api_key" {
  description = "Optional WatsonX API key. Leave empty to skip secret creation."
  type        = string
  default     = ""
  sensitive   = true
}

variable "watsonx_project_id" {
  description = "Optional WatsonX Project ID. Leave empty to skip secret creation."
  type        = string
  default     = ""
}
