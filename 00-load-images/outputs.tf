##############################################################################
# 00-load-images – outputs
##############################################################################

output "images_uploaded" {
  description = "Sentinel ID of the image-tool upload run."
  value       = null_resource.upload_images.id
}

output "target_registry" {
  description = "Registry the IDIG images were uploaded to (use as docker_registry in later steps)."
  value       = var.docker_registry
}

output "ifix_copied" {
  description = "Sentinel ID of the ifix copy. Empty string when install_ifix = false."
  value       = var.install_ifix ? null_resource.copy_ifix[0].id : ""
}
