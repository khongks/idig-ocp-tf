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

variable "idig_cr_name" {
  description = "Name of the IDIG cluster CR."
  type        = string
}

variable "idig_cluster_applied" {
  description = "Sentinel from 04-idig-cluster; re-runs verification after the CR changes."
  type        = string
}

variable "ready_timeout_seconds" {
  description = "How long to wait for phase Ready."
  type        = number
  default     = 1800
}
