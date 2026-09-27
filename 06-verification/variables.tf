##############################################################################
# 06-verification – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace where IDIG is deployed."
  type        = string
}
