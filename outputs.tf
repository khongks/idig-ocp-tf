##############################################################################
# IDIG on OpenShift – root outputs
##############################################################################

output "namespace" {
  description = "Namespace where IDIG is deployed."
  value       = var.namespace
}

output "idig_cr_name" {
  description = "Name of the IDIG cluster CR."
  value       = module.idig_cluster.idig_cr_name
}

output "admin_username" {
  description = "Username for the Console and Developer Portal."
  value       = module.access.admin_username
}

output "idig_platform_url" {
  description = "IDIG Console URL."
  value       = module.access.idig_platform_url
}

output "idig_admin_password_command" {
  description = "Command to print the Console admin password."
  value       = module.access.idig_admin_password_command
}

output "idig_dev_portal_url" {
  description = "Developer Portal URL (empty when disabled)."
  value       = module.access.idig_dev_portal_url
}

output "idig_devportal_password_command" {
  description = "Command to print the Developer Portal admin password (empty when disabled)."
  value       = module.access.idig_devportal_password_command
}

output "valkey_password" {
  description = "Generated Valkey password (secret valkey-secret)."
  value       = module.operators.valkey_password
  sensitive   = true
}

output "routes_command" {
  description = "Command to list the IDIG routes."
  value       = module.access.routes_command
}
