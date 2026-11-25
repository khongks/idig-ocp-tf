##############################################################################
# 03-operators – outputs
##############################################################################

output "idig_operator_ready" {
  description = "Sentinel: the IDIG operator is Available (changes when it is re-applied)."
  value       = null_resource.idig_operator.id
}

output "valkey_password" {
  description = "Generated Valkey password (also in secret valkey-secret)."
  value       = random_password.valkey.result
  sensitive   = true
}
