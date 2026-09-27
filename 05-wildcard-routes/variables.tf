##############################################################################
# 05-wildcard-routes – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "idig_cluster_applied" {
  description = "Trigger value from module.idig_cluster (idig_cluster_applied output) — forces re-run when the cluster CR changes."
  type        = string
}
