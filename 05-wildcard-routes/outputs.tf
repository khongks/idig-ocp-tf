##############################################################################
# 05-wildcard-routes – outputs
##############################################################################

output "wildcard_policy_applied" {
  description = "Sentinel: WildcardsAllowed was ensured (empty when skipped)."
  value       = var.enable_wildcard_routes ? null_resource.wildcard_policy[0].id : ""
}
