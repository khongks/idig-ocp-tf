##############################################################################
# IDIG on OpenShift – root variables
##############################################################################

# --- Cluster -----------------------------------------------------------------

variable "kubeconfig_path" {
  description = "Absolute path to the OCP kubeconfig. Used by the kubernetes provider and every oc call."
  type        = string
}

variable "namespace" {
  description = "Namespace for IDIG."
  type        = string
  default     = "idig-system"
}

variable "endpoint_domain" {
  description = "Base domain for IDIG endpoints, normally the cluster apps domain (apps.<cluster>.<domain>)."
  type        = string
}

# --- Release files and images ---------------------------------------------------

variable "release_files_path" {
  description = "Path to the extracted idig-operator-release-files_<version> directory."
  type        = string
  validation {
    condition     = fileexists("${var.release_files_path}/idig-crds.yaml") && fileexists("${var.release_files_path}/dependencies/ibm-apiconnect.yaml")
    error_message = "release_files_path must be an extracted IDIG release bundle (idig-crds.yaml, dependencies/ …)."
  }
}

variable "docker_registry" {
  description = "Registry path (host[/namespace], no scheme) the images were uploaded to by 00-load-images."
  type        = string
}

variable "docker_user" {
  description = "Username for the target registry."
  type        = string
}

variable "docker_password" {
  description = "Password / API key for the target registry."
  type        = string
  sensitive   = true
}

variable "ibm_entitlement_key" {
  description = "IBM Entitlement Key (cp.icr.io) for the DataPower Nano Gateway images."
  type        = string
  sensitive   = true
}

# --- Prerequisites ------------------------------------------------------------

variable "storage_class_name" {
  description = "StorageClass for IDIG (CR storageClassName, Analytics and Valkey PVCs). Empty = cluster default."
  type        = string
  default     = ""
}

variable "set_default_storage_class" {
  description = "Annotate storage_class_name as the cluster default StorageClass (cluster-wide)."
  type        = bool
  default     = false
}

variable "install_cert_manager" {
  description = "Install the cert-manager Operator for Red Hat OpenShift via OLM if missing. An existing install is detected and skipped automatically."
  type        = bool
  default     = true
}

variable "enable_wildcard_routes" {
  description = "Set wildcardPolicy=WildcardsAllowed on the default IngressController (cluster-wide)."
  type        = bool
  default     = true
}

# --- IDIG cluster CR ----------------------------------------------------------

variable "idig_cr_name" {
  description = "Name of the IDIG cluster CR. At most 5 characters (admission webhook limit)."
  type        = string
  default     = "idig"
  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,3}[a-z0-9])?$", var.idig_cr_name))
    error_message = "idig_cr_name must be a DNS label of 1–5 characters (lowercase letters, digits, '-')."
  }
}

variable "idig_version" {
  description = "spec.version. Fresh installs must use 12.1.1.3 (see operand-version.yaml)."
  type        = string
  default     = "12.1.1.3"
}

variable "idig_profile" {
  description = "Deployment profile: dev (minimal) or prod (HA)."
  type        = string
  default     = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.idig_profile)
    error_message = "idig_profile must be 'dev' or 'prod'."
  }
}

variable "idig_tenant_name" {
  description = "spec.tenantName."
  type        = string
  default     = "acme"
}

variable "idig_group_name" {
  description = "spec.groupName."
  type        = string
  default     = "sandbox"
}

variable "nanogw_gateway_domain" {
  description = "spec.nanoGateway.gatewayDomain. Empty = idig.<endpoint_domain>."
  type        = string
  default     = ""
}

variable "enable_analytics" {
  description = "Deploy Analytics. Worker nodes need vm.max_map_count >= 262144 (see configure_max_map_count)."
  type        = bool
  default     = true
}

variable "configure_max_map_count" {
  description = "When Analytics is enabled, ensure vm.max_map_count >= 262144 on workers via a Tuned profile (no reboot). Applied only if a worker is below it."
  type        = bool
  default     = true
}

variable "analytics_volume_size" {
  description = "Analytics shared volume size."
  type        = string
  default     = "200Gi"
}

variable "enable_dev_portal" {
  description = "Deploy the Developer Portal."
  type        = bool
  default     = true
}

variable "license_use" {
  description = "License use: nonproduction or production."
  type        = string
  default     = "nonproduction"
  validation {
    condition     = contains(["nonproduction", "production"], var.license_use)
    error_message = "license_use must be 'nonproduction' or 'production'."
  }
}

variable "license_id" {
  description = "License ID for spec.license.license."
  type        = string
  default     = "L-PAZT-LQ5TZL"
}

variable "runtime_log_level" {
  description = "Optional spec.runtimeConfig.logLevel (trace|debug|info|warn|error|off). Empty = operator default."
  type        = string
  default     = ""
  validation {
    condition     = contains(["", "trace", "debug", "info", "warn", "error", "off"], var.runtime_log_level)
    error_message = "runtime_log_level must be empty or one of trace, debug, info, warn, error, off."
  }
}

# --- Optional WatsonX (GenAI service) ----------------------------------------

variable "watsonx_api_key" {
  description = "WatsonX API key. Empty = GenAI service not deployed."
  type        = string
  default     = ""
  sensitive   = true
}

variable "watsonx_project_id" {
  description = "WatsonX Project ID (required with watsonx_api_key)."
  type        = string
  default     = ""
}
