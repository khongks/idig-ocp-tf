##############################################################################
# 00-load-images – variables
##############################################################################

variable "container_cli" {
  description = "Container CLI to use: \"auto\" (podman if installed, else docker), \"podman\" or \"docker\"."
  type        = string
  default     = "auto"
  validation {
    condition     = contains(["auto", "podman", "docker"], var.container_cli)
    error_message = "container_cli must be one of: auto, podman, docker."
  }
}

variable "image_tar_path" {
  description = "Absolute path to the IBM image-tool archive (idig-image-tool-<version>.tar.gz from the operator release files)."
  type        = string
  default     = ""
}

variable "image_tool_ref" {
  description = <<-EOT
    Reference of an already-loaded image-tool image (e.g. idig-image-tool-12.1.1:latest).
    When set, the `load` step is skipped and image_tar_path is ignored. Leave empty to load
    from image_tar_path. Note: different fix packs can share the same tool image name, so
    prefer loading from the archive unless you are sure which version is loaded.
  EOT
  type        = string
  default     = ""
}

variable "image_tool_platform" {
  description = "Platform passed to `run --platform` for the image tool. The tool image is linux/amd64; set \"\" to omit the flag."
  type        = string
  default     = "linux/amd64"
}

variable "docker_registry" {
  description = "Target registry path (host[/namespace]) passed to `image-tool upload`, e.g. myregistry.example.com/idig."
  type        = string
  validation {
    condition     = length(trimspace(var.docker_registry)) > 0 && !can(regex("^[a-z]+://", var.docker_registry))
    error_message = "docker_registry must be set and must not include a scheme (no https://)."
  }
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

variable "upload_extra_args" {
  description = "Extra arguments appended to `image-tool upload <registry>` (see `image-tool upload --help`)."
  type        = list(string)
  default     = []
}

variable "registry_tls_verify" {
  description = "Verify TLS for the target registry when copying ifix images with skopeo."
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------
# Optional – LA iFix (v12.1.1.2 with Analytics only; skip on v12.1.1.3+)
# ---------------------------------------------------------------------------

variable "install_ifix" {
  description = "Copy the LA iFix images from ifix_archive_path into the target registry with skopeo. Only for v12.1.1.2 with Analytics."
  type        = bool
  default     = false
}

variable "ifix_archive_path" {
  description = "Absolute path to the ifix archive, e.g. interact-gateway-v12.1.1.2-ifix1.AM-3536.tar.gz."
  type        = string
  default     = ""
}

variable "ifix_images" {
  description = <<-EOT
    Images to copy from the extracted ifix archive. source_dir is the skopeo dir: layout path
    relative to the archive root; dest is <repo>:<tag> appended to docker_registry.
  EOT
  type = list(object({
    source_dir = string
    dest       = string
  }))
  default = []
}
