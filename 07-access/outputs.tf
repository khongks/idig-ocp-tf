##############################################################################
# 07-access – outputs
##############################################################################

output "idig_platform_url" {
  description = "URL of the IDIG platform UI."
  value       = local.idig_platform_url
}

output "idig_admin_password_command" {
  description = "oc command to retrieve the IDIG admin password from the cluster."
  value       = local.admin_password_cmd
}

output "idig_devportal_password_command" {
  description = "oc command to retrieve the Developer Portal admin password from the cluster."
  value       = local.devportal_password_cmd
}

output "idig_dev_portal_url" {
  description = "URL of the IDIG Developer Portal UI."
  value       = local.idig_devportal_url
}
