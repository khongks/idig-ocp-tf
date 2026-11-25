##############################################################################
# 03-operators – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the IDIG deployment."
  type        = string
}

variable "docker_registry" {
  description = "Target registry path (host[/namespace]) holding the IDIG images."
  type        = string
}

variable "image_pull_secret" {
  description = "Pull secret name substituted for DEFAULT_IMAGE_PULL_SECRET."
  type        = string
  default     = "apic-registry-secret"
}

variable "release_files_path" {
  description = "Local path to the extracted IDIG release files (contains dependencies/)."
  type        = string
}

variable "storage_class_name" {
  description = "StorageClass for the Valkey PVC (REPLACE-STORAGE-CLASS). Empty = cluster default."
  type        = string
  default     = ""
}

variable "valkey_cert_validity_hours" {
  description = "Validity of the generated Valkey CA and server certificates."
  type        = number
  default     = 26280 # 3 years
}
