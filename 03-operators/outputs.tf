##############################################################################
# 03-operators – outputs
##############################################################################

output "apic_operator_ready" {
  description = "Trigger value indicating the APIC operator is Available."
  value       = null_resource.wait_apic_operator.id
}

output "nanogw_operator_ready" {
  description = "Trigger value indicating the NanoGateway operator is deployed."
  value       = null_resource.deploy_nanogw_operator.id
}

output "valkey_instance_ready" {
  description = "Trigger value indicating the Valkey instance pods are ready."
  value       = null_resource.wait_valkey_instance.id
}

output "idig_nanogw_operator_ready" {
  description = "Trigger value indicating the IDIG NanoGateway operator is Available."
  value       = null_resource.wait_idig_nanogw_operator.id
}

output "idig_operator_ready" {
  description = "Trigger value indicating the IDIG operator is Available."
  value       = null_resource.wait_idig_operator.id
}
