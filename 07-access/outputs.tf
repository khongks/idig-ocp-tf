##############################################################################
# 07-access – outputs
##############################################################################

output "admin_username" {
  description = "Username for the IDIG Console and Developer Portal."
  value       = "administrator"
}

output "idig_platform_url" {
  description = "IDIG Console URL."
  value       = "https://idig.${var.endpoint_domain}"
}

output "idig_admin_password_command" {
  description = "Command to print the IDIG Console admin password."
  value       = format(local.password_cmd, "${var.idig_cr_name}-idig-admin-pass")
}

output "idig_dev_portal_url" {
  description = "Developer Portal URL (empty when the Developer Portal is disabled)."
  value       = var.enable_dev_portal ? "https://devportal.${var.endpoint_domain}" : ""
}

output "idig_devportal_password_command" {
  description = "Command to print the Developer Portal admin password (empty when disabled)."
  value       = var.enable_dev_portal ? format(local.password_cmd, "${var.idig_cr_name}-devportal-admin-secret") : ""
}

output "routes_command" {
  description = "Command to list the routes created by the IDIG operators."
  value       = "oc get routes -n ${var.namespace}"
}
