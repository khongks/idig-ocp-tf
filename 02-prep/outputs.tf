##############################################################################
# 02-prep – outputs
##############################################################################

output "apic_registry_secret_name" {
  description = "Name of the registry pull secret for the target registry."
  value       = kubernetes_secret_v1.apic_registry_secret.metadata[0].name
}

output "ibm_entitlement_secret_name" {
  description = "Name of the IBM entitlement key secret for cp.icr.io."
  value       = kubernetes_secret_v1.ibm_entitlement_key.metadata[0].name
}

output "watsonx_secret_name" {
  description = "Name of the Watsonx credentials secret (empty string if not created)."
  value       = var.watsonx_api_key != "" ? kubernetes_secret_v1.watsonx_credentials[0].metadata[0].name : ""
}
