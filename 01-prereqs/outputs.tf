##############################################################################
# 01-prereqs – outputs
##############################################################################

output "namespace_name" {
  description = "The namespace created for IDIG."
  value       = kubernetes_namespace_v1.idig.metadata[0].name
}

output "ingress_issuer_ready" {
  description = "Sentinel: ingress-issuer and its certificates are Ready."
  value       = null_resource.ingress_issuer.id
}
