##############################################################################
# 00-load-images – outputs
##############################################################################

output "images_loaded" {
  description = "Sentinel value confirming the image archive was loaded and pushed to the target registry."
  value       = null_resource.load_images.id
}

output "ifix_copied" {
  description = "Sentinel value confirming the ifix image was copied via skopeo. Empty string when install_ifix = false."
  value       = var.install_ifix ? null_resource.copy_ifix[0].id : ""
}
