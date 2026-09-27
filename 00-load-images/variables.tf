##############################################################################
# 00-load-images – variables
##############################################################################

variable "image_tar_path" {
  description = "Absolute path to the IDIG image archive (.tar or .tgz) to load into the target registry."
  type        = string
}

variable "docker_registry" {
  description = "Target container registry URL to push images into (e.g. myregistry.example.com/idig)."
  type        = string
}

variable "docker_user" {
  description = "Username for the target container registry."
  type        = string
}

variable "docker_password" {
  description = "Password / API key for the target container registry."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Optional – ifix via skopeo
# ---------------------------------------------------------------------------

variable "install_ifix" {
  description = "Set to true to copy an ifix image from a source registry into the target registry using skopeo."
  type        = bool
  default     = false
}

variable "ifix_source_image" {
  description = <<-EOT
    Full source image reference for the ifix (e.g. cp.icr.io/cp/datapower/idig:12.1.1.2-ifix1).
    Required when install_ifix = true; ignored otherwise.
  EOT
  type        = string
  default     = ""
}

variable "ifix_dest_image" {
  description = <<-EOT
    Full destination image reference for the ifix in the target registry
    (e.g. myregistry.example.com/idig/idig:12.1.1.2-ifix1).
    Required when install_ifix = true; ignored otherwise.
  EOT
  type        = string
  default     = ""
}

variable "ifix_source_creds" {
  description = <<-EOT
    Credentials for the ifix source registry in user:password format
    (e.g. cp:<IBM_ENTITLEMENT_KEY>).
    Required when install_ifix = true; ignored otherwise.
  EOT
  type      = string
  default   = ""
  sensitive = true
}
