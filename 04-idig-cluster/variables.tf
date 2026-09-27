##############################################################################
# 04-idig-cluster – variables
##############################################################################

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig YAML file."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace for the IDIG deployment."
  type        = string
}

variable "endpoint_domain" {
  description = "Full apps subdomain of the OCP cluster (e.g. apps.mycluster.example.com)."
  type        = string
}

variable "docker_registry" {
  description = "Target container registry URL."
  type        = string
}

variable "idig_profile" {
  description = "Deployment profile: dev or prod."
  type        = string
  default     = "dev"
}

variable "idig_tenant_name" {
  description = "Tenant name for the IDIG cluster CR."
  type        = string
  default     = "acme"
}

variable "idig_group_name" {
  description = "Group name for the IDIG cluster CR."
  type        = string
  default     = "sandbox"
}

variable "storage_class_name" {
  description = "StorageClass name for IDIG Analytics PVs. Leave empty to use cluster default."
  type        = string
  default     = ""
}

variable "analytics_volume_size" {
  description = "Shared storage volume size for the Analytics component (e.g. 200Gi)."
  type        = string
  default     = "200Gi"
}

variable "enable_analytics" {
  description = "Deploy the Analytics component."
  type        = bool
  default     = true
}

variable "enable_dev_portal" {
  description = "Deploy the Developer Portal component."
  type        = bool
  default     = true
}

variable "license_use" {
  description = "License use: nonproduction or production."
  type        = string
  default     = "nonproduction"
}

variable "idig_version" {
  description = "IDIG product version string for the cluster CR (e.g. 12.1.1.2)."
  type        = string
  default     = "12.1.1.2"
}

variable "license_id" {
  description = "IBM license identifier for the IDIG cluster CR (e.g. L-PAZT-LQ5TZL)."
  type        = string
  default     = "L-PAZT-LQ5TZL"
}

variable "watsonx_api_key" {
  description = "Optional WatsonX API key. When non-empty, watsonxSecret is included in the cluster CR."
  type        = string
  default     = ""
  sensitive   = true
}

variable "operators_ready" {
  description = "Trigger value from module.operators (idig_operator_ready output) — forces re-run when operators change."
  type        = string
}

variable "release_files_path" {
  description = "Local path to the extracted IDIG product release files directory."
  type        = string
}
