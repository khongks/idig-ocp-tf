##############################################################################
# 07-access – variables
##############################################################################

variable "namespace" {
  description = "Kubernetes namespace where IDIG is deployed."
  type        = string
}

variable "idig_cr_name" {
  description = "Name of the IDIG cluster CR."
  type        = string
}

variable "endpoint_domain" {
  description = "Base domain for the IDIG endpoints."
  type        = string
}

variable "enable_dev_portal" {
  description = "Whether the Developer Portal is enabled."
  type        = bool
}
