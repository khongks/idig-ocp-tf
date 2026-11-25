##############################################################################
# 04-idig-cluster – outputs
##############################################################################

output "idig_cr_name" {
  description = "Name of the IDIG cluster custom resource."
  value       = var.idig_cr_name
}

output "idig_cluster_applied" {
  description = "Sentinel: the IDIG cluster CR was applied."
  value       = null_resource.idig_cluster.id
}
