##############################################################################
# 06-verification – outputs
##############################################################################

output "idig_ready" {
  description = "Sentinel: the IDIG cluster reached phase Ready."
  value       = null_resource.wait_idig_ready.id
}
