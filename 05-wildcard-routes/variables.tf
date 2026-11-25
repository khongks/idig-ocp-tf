##############################################################################
# 05-wildcard-routes – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "enable_wildcard_routes" {
  description = "Patch the default IngressController to WildcardsAllowed (cluster-wide)."
  type        = bool
  default     = true
}
