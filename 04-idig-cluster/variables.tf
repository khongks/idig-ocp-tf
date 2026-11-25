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

variable "release_files_path" {
  description = "Local path to the extracted IDIG release files (contains idig-crds.yaml)."
  type        = string
}

variable "idig_cr_name" {
  description = "metadata.name of the IDIG cluster CR. Max 5 characters (enforced by the admission webhook)."
  type        = string
  default     = "idig"
}

variable "endpoint_domain" {
  description = "Base domain for all endpoints, e.g. apps.mycluster.example.com."
  type        = string
}

variable "nanogw_gateway_domain" {
  description = "spec.nanoGateway.gatewayDomain. Empty = idig.<endpoint_domain> (12.1.1.3 sample default)."
  type        = string
  default     = ""
}

variable "docker_registry" {
  description = "Target registry path (host[/namespace]) holding the IDIG images."
  type        = string
}

variable "image_pull_secret" {
  description = "Pull secret for the target registry."
  type        = string
  default     = "apic-registry-secret"
}

variable "idig_version" {
  description = "spec.version of the IDIG cluster."
  type        = string
}

variable "idig_profile" {
  description = "Deployment profile: dev or prod."
  type        = string
}

variable "idig_tenant_name" {
  description = "spec.tenantName."
  type        = string
}

variable "idig_group_name" {
  description = "spec.groupName."
  type        = string
}

variable "storage_class_name" {
  description = "spec.storageClassName (and Analytics storage). Empty = cluster default."
  type        = string
  default     = ""
}

variable "analytics_volume_size" {
  description = "Analytics shared volume size."
  type        = string
  default     = "200Gi"
}

variable "enable_analytics" {
  description = "spec.enableAnalytics."
  type        = bool
}

variable "enable_dev_portal" {
  description = "spec.enableDevPortal."
  type        = bool
}

variable "license_use" {
  description = "spec.license.use: nonproduction or production."
  type        = string
}

variable "license_id" {
  description = "spec.license.license."
  type        = string
}

variable "watsonx_secret_name" {
  description = "Name of the WatsonX credentials secret; empty omits spec.watsonxSecret (no GenAI service)."
  type        = string
  default     = ""
}

variable "runtime_log_level" {
  description = "Optional spec.runtimeConfig.logLevel (trace|debug|info|warn|error|off). Empty omits it."
  type        = string
  default     = ""
}

variable "operators_ready" {
  description = "Sentinel from 03-operators; re-applies the CR when the IDIG operator is re-applied."
  type        = string
}
