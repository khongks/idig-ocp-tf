##############################################################################
# 01-prereqs – main.tf
#
# OpenShift prerequisites:
#   1. Create the IDIG namespace
#   2. Storage – verify a default StorageClass exists (optionally annotate one)
#   3. cert-manager Operator for Red Hat OpenShift via OLM
#   4. ingress-issuer (helper_files/ingress-issuer-v1.yaml) in the IDIG namespace
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-installing-prerequisite-components
##############################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

locals {
  ingress_issuer_file = "${var.release_files_path}/helper_files/ingress-issuer-v1.yaml"
}

# ---------------------------------------------------------------------------
# 1. IDIG namespace
# ---------------------------------------------------------------------------
resource "kubernetes_namespace_v1" "idig" {
  metadata {
    name = var.namespace
    labels = {
      "app.kubernetes.io/managed-by" = "opentofu"
      "app.kubernetes.io/part-of"    = "idig"
    }
  }
}

# ---------------------------------------------------------------------------
# 2. Storage
#
# The APIC Analytics webhook requires a StorageClass annotated
# storageclass.kubernetes.io/is-default-class=true. Optionally annotate
# var.storage_class_name, then fail early if no default exists.
# ---------------------------------------------------------------------------
resource "null_resource" "default_storage_class" {
  triggers = {
    storage_class = var.storage_class_name
    annotate      = tostring(var.set_default_storage_class)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -euo pipefail
      SC="${var.storage_class_name}"

      if [[ -n "$SC" ]] && ! oc get sc "$SC" >/dev/null 2>&1; then
        echo "ERROR: StorageClass '$SC' not found." >&2
        oc get sc >&2
        exit 1
      fi

      if [[ "${var.set_default_storage_class}" == "true" ]]; then
        oc annotate sc "$SC" storageclass.kubernetes.io/is-default-class=true --overwrite
      fi

      DEFAULTS=$(oc get sc -o jsonpath='{range .items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")]}{.metadata.name}{"\n"}{end}')
      if [[ -z "$DEFAULTS" ]]; then
        echo "ERROR: no default StorageClass. Set set_default_storage_class = true or annotate one manually." >&2
        exit 1
      fi
      if [[ $(wc -l <<< "$DEFAULTS") -gt 1 ]]; then
        echo "WARNING: more than one default StorageClass:"; echo "$DEFAULTS"
      fi
      echo "Default StorageClass: $DEFAULTS"
    EOT
  }

  lifecycle {
    precondition {
      condition     = !var.set_default_storage_class || var.storage_class_name != ""
      error_message = "set_default_storage_class = true requires storage_class_name."
    }
  }
}

# ---------------------------------------------------------------------------
# 2b. vm.max_map_count for Analytics (OpenSearch) – workers need >= 262144
#
# Checks every worker; only if one is below the minimum, applies a Tuned
# profile via the built-in Node Tuning Operator (live, no reboot) and waits
# until all workers report the new value. vm.* sysctls are node-global, so
# the value is read from the tuned DaemonSet pod on each node.
# The Tuned CR is left in place on destroy (removing it would revert nodes).
# ---------------------------------------------------------------------------
resource "null_resource" "max_map_count" {
  count = var.enable_analytics && var.configure_max_map_count ? 1 : 0

  triggers = {
    min = tostring(var.max_map_count)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
      MIN        = tostring(var.max_map_count)
    }
    command = <<-EOT
      set -euo pipefail
      NTO=openshift-cluster-node-tuning-operator

      # Prints "<node> <value>" for every worker; returns 1 if any is below MIN.
      check() {
        local low=0 node pod v
        for node in $(oc get nodes -l node-role.kubernetes.io/worker -o jsonpath='{.items[*].metadata.name}'); do
          pod=$(oc -n $NTO get pods -l openshift-app=tuned --field-selector spec.nodeName="$node" -o jsonpath='{.items[0].metadata.name}')
          v=$(oc -n $NTO exec "$pod" -- cat /proc/sys/vm/max_map_count)
          echo "  $node vm.max_map_count=$v"
          (( v >= MIN )) || low=1
        done
        return $low
      }

      echo "Checking vm.max_map_count on worker nodes (need >= $MIN)..."
      if check; then
        echo "All workers OK – no change."
        exit 0
      fi

      echo "Applying Tuned profile idig-max-map-count..."
      oc apply -f - <<EOF
      apiVersion: tuned.openshift.io/v1
      kind: Tuned
      metadata:
        name: idig-max-map-count
        namespace: $NTO
      spec:
        profile:
          - name: idig-max-map-count
            data: |
              [main]
              summary=IDIG Analytics - raise vm.max_map_count
              include=openshift-node
              [sysctl]
              vm.max_map_count=$MIN
        recommend:
          - match:
              - label: node-role.kubernetes.io/worker
            priority: 20
            profile: idig-max-map-count
      EOF

      for i in $(seq 1 30); do
        sleep 10
        if check >/dev/null; then
          check
          echo "vm.max_map_count applied on all workers."
          exit 0
        fi
      done
      check || true
      echo "ERROR: vm.max_map_count not applied after 5 min. Check: oc get profiles.tuned.openshift.io -n $NTO" >&2
      exit 1
    EOT
  }
}

# ---------------------------------------------------------------------------
# 3. cert-manager Operator for Red Hat OpenShift (OLM)
#
# Auto-detects an existing install and skips it:
#   • An OLM Subscription for openshift-cert-manager-operator exists (any
#     namespace) → already installed, nothing is created.
#   • cert-manager CRDs exist but no such Subscription → community
#     cert-manager, which is NOT supported on OCP (APIC reports
#     OperatorDependencyNotInstalled) → fail with an explanation.
#   • Otherwise, and install_cert_manager = true → create the namespace,
#     OperatorGroup and Subscription (as the OperatorHub UI does).
# Then waits for cert-manager to be serving.
#
# Done with `oc` rather than kubernetes_* resources so an existing install is
# never adopted or deleted, and destroy leaves this shared, cluster-wide
# operator in place.
# ---------------------------------------------------------------------------
resource "null_resource" "cert_manager" {
  triggers = {
    install = tostring(var.install_cert_manager)
    channel = var.cert_manager_channel
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = {
      KUBECONFIG = var.kubeconfig_path
      INSTALL    = tostring(var.install_cert_manager)
      CHANNEL    = var.cert_manager_channel
    }
    command = <<-EOT
      set -euo pipefail
      PKG=openshift-cert-manager-operator

      SUB=$(oc get subscriptions.operators.coreos.com -A \
        -o jsonpath="{range .items[?(@.spec.name=='$PKG')]}{.metadata.namespace}/{.metadata.name}{'\n'}{end}")

      if [[ -n "$SUB" ]]; then
        echo "cert-manager Operator for Red Hat OpenShift already installed ($SUB) – skipping install."
      elif oc get crd certificates.cert-manager.io >/dev/null 2>&1; then
        echo "ERROR: cert-manager CRDs exist but there is no OLM subscription for $PKG." >&2
        echo "       IDIG/APIC on OpenShift needs the cert-manager Operator for Red Hat OpenShift (OLM);" >&2
        echo "       the community cert-manager is not supported." >&2
        exit 1
      elif [[ "$INSTALL" != "true" ]]; then
        echo "ERROR: cert-manager is not installed and install_cert_manager = false." >&2
        exit 1
      else
        echo "Installing cert-manager Operator for Red Hat OpenShift (channel $CHANNEL)..."
        oc apply -f - <<EOF
      apiVersion: v1
      kind: Namespace
      metadata:
        name: cert-manager-operator
      ---
      apiVersion: operators.coreos.com/v1
      kind: OperatorGroup
      metadata:
        name: cert-manager-operator
        namespace: cert-manager-operator
      spec:
        targetNamespaces:
          - cert-manager-operator
      ---
      apiVersion: operators.coreos.com/v1alpha1
      kind: Subscription
      metadata:
        name: $PKG
        namespace: cert-manager-operator
      spec:
        channel: $CHANNEL
        name: $PKG
        source: redhat-operators
        sourceNamespace: openshift-marketplace
        installPlanApproval: Automatic
      EOF
      fi

      echo "Waiting for cert-manager (up to 10 min)..."
      for i in $(seq 1 60); do
        if oc get crd issuers.cert-manager.io >/dev/null 2>&1 \
           && oc -n cert-manager get deployment cert-manager-webhook >/dev/null 2>&1; then
          oc wait crd/issuers.cert-manager.io crd/certificates.cert-manager.io \
            --for=condition=Established --timeout=60s
          oc -n cert-manager wait deployment --all --for=condition=Available --timeout=300s
          echo "cert-manager is ready."
          exit 0
        fi
        sleep 10
      done
      echo "ERROR: cert-manager did not become ready. Check: oc get csv -A | grep cert-manager" >&2
      exit 1
    EOT
  }
}

# ---------------------------------------------------------------------------
# 4. ingress-issuer + IDIG client certificates (namespaced)
#      oc apply -f helper_files/ingress-issuer-v1.yaml -n <namespace>
# ---------------------------------------------------------------------------
resource "null_resource" "ingress_issuer" {
  triggers = {
    file_sha  = filesha256(local.ingress_issuer_file)
    namespace = var.namespace
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -euo pipefail
      oc apply -f "${local.ingress_issuer_file}" -n "${var.namespace}"
      # Every Issuer/Certificate in the file exposes a Ready condition.
      oc wait -f "${local.ingress_issuer_file}" -n "${var.namespace}" \
        --for=condition=Ready --timeout=180s
      oc get issuers -n "${var.namespace}"
    EOT
  }

  depends_on = [
    kubernetes_namespace_v1.idig,
    null_resource.cert_manager,
  ]
}
