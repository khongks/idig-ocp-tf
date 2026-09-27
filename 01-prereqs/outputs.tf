##############################################################################
# 01-prereqs – outputs
##############################################################################

output "namespace_name" {
  description = "The namespace that was created for IDIG."
  value       = kubernetes_namespace_v1.idig.metadata[0].name
}

output "ingress_issuer_applied" {
  description = "Indicates that the ingress-ca ClusterIssuer chain is ready."
  value       = null_resource.wait_ingress_issuer.id
}
