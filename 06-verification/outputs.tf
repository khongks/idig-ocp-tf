##############################################################################
# 06-verification – outputs
##############################################################################

output "idig_ready" {
  description = "Trigger value indicating the IDIG cluster reached Ready phase."
  value       = null_resource.wait_idig_ready.id
}
