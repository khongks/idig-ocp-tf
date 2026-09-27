##############################################################################
# 05-wildcard-routes – main.tf
#
# Patches the default OCP IngressController to allow wildcard routes so that
# the DataPower NanoGateway wildcard route is accepted.
#
# The patch sets:
#   spec.routeAdmission.wildcardPolicy: WildcardsAllowed
#
# IMPORTANT: This is a cluster-wide change that affects all routes on the
# cluster. Consult your cluster administrator before applying.
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-enabling-wildcard-routes-datapower-nanogateway
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

resource "null_resource" "patch_ingress_controller" {
  triggers = {
    kubeconfig            = var.kubeconfig_path
    idig_cluster_applied  = var.idig_cluster_applied
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"

      echo "Patching default IngressController to allow wildcard routes..."
      oc -n openshift-ingress-operator patch ingresscontroller/default \
        --type=merge \
        -p '{"spec":{"routeAdmission":{"wildcardPolicy":"WildcardsAllowed"}}}'

      echo "Waiting for IngressController pods to restart..."
      sleep 15
      oc rollout status deployment/router-default \
        -n openshift-ingress --timeout=120s || true

      echo "Verifying wildcard policy..."
      oc -n openshift-ingress-operator get ingresscontroller/default \
        -o jsonpath='{.spec.routeAdmission.wildcardPolicy}'
      echo ""
      echo "Wildcard routes enabled on default IngressController."
    EOT
  }
}
