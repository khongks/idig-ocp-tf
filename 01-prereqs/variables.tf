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

variable "release_files_path" {
  description = "Local path to the extracted IDIG release files (contains helper_files/)."
  type        = string
}

variable "storage_class_name" {
  description = "StorageClass for IDIG (verified to exist). Empty = rely on the cluster default."
  type        = string
  default     = ""
}

variable "set_default_storage_class" {
  description = "Annotate storage_class_name as the cluster default StorageClass (cluster-wide change)."
  type        = bool
  default     = false
}

variable "enable_analytics" {
  description = "Whether Analytics will be deployed (vm.max_map_count is only needed then)."
  type        = bool
  default     = true
}

variable "configure_max_map_count" {
  description = "Ensure vm.max_map_count >= max_map_count on workers via a Tuned profile (only when Analytics is enabled)."
  type        = bool
  default     = true
}

variable "max_map_count" {
  description = "Minimum vm.max_map_count required on worker nodes for Analytics."
  type        = number
  default     = 262144
}

variable "install_cert_manager" {
  description = "Install the cert-manager Operator for Red Hat OpenShift via OLM when it is not already installed (existing installs are detected and skipped)."
  type        = bool
  default     = true
}

variable "cert_manager_channel" {
  description = "OLM channel for the cert-manager Operator for Red Hat OpenShift."
  type        = string
  default     = "stable-v1"
}
