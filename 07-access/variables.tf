##############################################################################
# 07-access – variables
##############################################################################

variable "namespace" {
  description = "Kubernetes namespace where IDIG is deployed."
  type        = string
}

variable "idig_cr_name" {
  description = "Name of the IDIG cluster custom resource."
  type        = string
}

variable "endpoint_domain" {
  description = "Full apps subdomain of the OCP cluster."
  type        = string
}
