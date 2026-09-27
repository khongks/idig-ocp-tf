##############################################################################
# 04-idig-cluster – outputs
##############################################################################

output "idig_cr_name" {
  description = "Name of the deployed IDIG cluster custom resource."
  value       = "idig"
}

output "idig_cluster_applied" {
  description = "Trigger value indicating the IDIG cluster CR was applied."
  value       = null_resource.deploy_idig_cluster.id
}
