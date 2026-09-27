##############################################################################
# 06-verification – main.tf
#
# Waits for the IDIG cluster CR to reach the Ready phase (up to 20 minutes),
# then verifies that all pods are running and lists the OCP routes.
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-verifying-installation-accessing-idig
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
    namespace  = var.namespace
    kubeconfig = var.kubeconfig_path
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      echo "Waiting for IDIG cluster to reach Ready phase (up to 20 minutes)..."
      timeout=1200
      while [ $timeout -gt 0 ]; do
        phase=$(oc get idig -n "${var.namespace}" \
          -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "")
        echo "  Phase: $${phase:-<not set>} ($${timeout}s remaining)"
        if [ "$phase" = "Ready" ]; then
          echo "IDIG cluster is Ready!"
          break
        fi
        sleep 30
        timeout=$(( timeout - 30 ))
      done

      if [ "$phase" != "Ready" ]; then
        echo "ERROR: IDIG cluster did not reach Ready phase within 20 minutes."
        exit 1
      fi

      echo ""
      echo "--- Pod status ---"
      oc get pods -n "${var.namespace}"

      echo ""
      echo "--- OpenShift Routes ---"
      oc get routes -n "${var.namespace}"

      echo ""
      echo "--- NanoGateway wildcard route ---"
      oc get routes -n "${var.namespace}" | grep nanogw || echo "nanogw route not yet visible"

      echo ""
      echo "--- Verifying wildcard route is admitted ---"
      CR_NAME=$(oc get idig -n "${var.namespace}" -o jsonpath='{.items[0].metadata.name}')
      NANOGW_ROUTE="$${CR_NAME}-nanogw-nanogw"
      ADMITTED=$(oc get route "$${NANOGW_ROUTE}" -n "${var.namespace}" \
        -o jsonpath='{.status.ingress[0].conditions[?(@.type=="Admitted")].status}' 2>/dev/null || echo "")
      echo "NanoGateway route admitted: $${ADMITTED:-unknown}"
    EOT
  }
}
