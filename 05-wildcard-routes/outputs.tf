##############################################################################
# 05-wildcard-routes – outputs
##############################################################################

output "wildcard_policy_applied" {
  description = "Trigger value indicating the WildcardsAllowed policy was patched."
  value       = null_resource.patch_ingress_controller.id
}
