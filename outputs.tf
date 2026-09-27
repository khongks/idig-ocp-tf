##############################################################################
# IBM DataPower Interact Gateway – root outputs
##############################################################################

output "idig_platform_url" {
  description = "URL of the IDIG platform UI."
  value       = module.access.idig_platform_url
}

output "idig_admin_password_command" {
  description = "oc command to retrieve the IDIG admin password."
  value       = module.access.idig_admin_password_command
}

output "idig_devportal_password_command" {
  description = "oc command to retrieve the Developer Portal admin password."
  value       = module.access.idig_devportal_password_command
}

output "idig_dev_portal_url" {
  description = "URL of the IDIG Developer Portal UI."
  value       = module.access.idig_dev_portal_url
}

output "idig_cr_name" {
  description = "Name of the deployed IDIG cluster custom resource."
  value       = module.idig_cluster.idig_cr_name
}

output "namespace" {
  description = "Kubernetes namespace where IDIG is deployed."
  value       = var.namespace
}
