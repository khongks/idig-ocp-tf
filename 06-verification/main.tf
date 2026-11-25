##############################################################################
# 06-verification – main.tf
#
# Waits for the IDIG cluster CR to reach phase Ready, then prints pods and
# routes and checks that the NanoGateway wildcard route is admitted.
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-verifying-installation-accessing-idig
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

resource "null_resource" "wait_idig_ready" {
  triggers = {
    idig_cluster_applied = var.idig_cluster_applied
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -uo pipefail
      NS="${var.namespace}"
      CR="${var.idig_cr_name}"
      KIND=datapowerinteractgatewaycluster
      TIMEOUT=${var.ready_timeout_seconds}

      echo "Waiting for $KIND/$CR to reach phase Ready (up to $((TIMEOUT / 60)) min)..."
      phase=""
      while (( TIMEOUT > 0 )); do
        phase=$(oc get $KIND "$CR" -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || true)
        [[ "$phase" == "Ready" ]] && break
        echo "  phase: $${phase:-<not set>}  ($${TIMEOUT}s remaining)"
        sleep 30
        TIMEOUT=$((TIMEOUT - 30))
      done

      echo; oc get $KIND "$CR" -n "$NS"
      echo; oc get pods -n "$NS"
      echo; oc get routes -n "$NS"

      if [[ "$phase" != "Ready" ]]; then
        echo; echo "ERROR: $CR did not reach Ready. Status conditions:" >&2
        oc get $KIND "$CR" -n "$NS" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}' >&2
        exit 1
      fi

      ROUTE="$CR-nanogw-nanogw"
      ADMITTED=$(oc get route "$ROUTE" -n "$NS" \
        -o jsonpath='{.status.ingress[0].conditions[?(@.type=="Admitted")].status}' 2>/dev/null || true)
      echo; echo "NanoGateway wildcard route $ROUTE admitted: $${ADMITTED:-unknown}"
      if [[ "$ADMITTED" != "True" ]]; then
        echo "WARNING: wildcard route not admitted – check the IngressController wildcardPolicy (05-wildcard-routes)."
      fi
      echo "IDIG cluster is Ready."
    EOT
  }
}
