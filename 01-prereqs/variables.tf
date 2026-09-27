##############################################################################
# 01-prereqs – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the IDIG deployment."
  type        = string
}

variable "storage_class_name" {
  description = "StorageClass name to annotate as default (leave empty to skip)."
  type        = string
  default     = ""
}

variable "analytics_volume_size" {
  description = "Shared storage volume size for the Analytics component (e.g. 200Gi)."
  type        = string
  default     = "200Gi"
}
