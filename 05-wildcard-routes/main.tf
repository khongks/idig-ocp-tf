##############################################################################
# 05-wildcard-routes – main.tf
#
# Sets spec.routeAdmission.wildcardPolicy=WildcardsAllowed on the default
# IngressController so the NanoGateway wildcard Route is admitted.
#
# CLUSTER-WIDE change – get cluster-admin approval. Set
# enable_wildcard_routes = false to skip (e.g. already configured).
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-enabling-wildcard-routes-datapower-nanogateway
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

resource "null_resource" "wildcard_policy" {
  count = var.enable_wildcard_routes ? 1 : 0

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -euo pipefail
      IC=ingresscontroller/default
      CURRENT=$(oc -n openshift-ingress-operator get $IC -o jsonpath='{.spec.routeAdmission.wildcardPolicy}')
      if [[ "$CURRENT" == "WildcardsAllowed" ]]; then
        echo "Wildcard routes already allowed."
        exit 0
      fi
      oc -n openshift-ingress-operator patch $IC --type=merge \
        -p '{"spec":{"routeAdmission":{"wildcardPolicy":"WildcardsAllowed"}}}'
      echo "Waiting for router rollout..."
      sleep 10
      oc -n openshift-ingress rollout status deployment/router-default --timeout=600s
      echo "wildcardPolicy: $(oc -n openshift-ingress-operator get $IC -o jsonpath='{.spec.routeAdmission.wildcardPolicy}')"
    EOT
  }
}
