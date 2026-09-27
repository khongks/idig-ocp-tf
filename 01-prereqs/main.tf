##############################################################################
# 01-prereqs – main.tf
#
# Implements the four prerequisite steps from the IDIG installation docs:
#   1. Create the IDIG namespace
#   2. Configure persistent storage for the Analytics component
#   3. Install cert-manager via OpenShift OLM
#   4. Install and configure the ingress-ca ClusterIssuer
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-installing-prerequisite-components
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

# ---------------------------------------------------------------------------
# Step 1 – Create the IDIG namespace
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
# Step 2 – Configure persistent storage for the Analytics component
#
# 2a. Annotate the specified StorageClass as the cluster default so that
#     the Analytics PVC can be dynamically provisioned.
#     Skipped when storage_class_name is empty (cluster default already set).
#
# 2b. Verify the StorageClass exists and is available before proceeding.
# ---------------------------------------------------------------------------
resource "null_resource" "configure_analytics_storage" {
  count = var.storage_class_name != "" ? 1 : 0

  triggers = {
    storage_class        = var.storage_class_name
    analytics_volume_size = var.analytics_volume_size
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"

      # Verify the StorageClass exists
      if ! oc get sc "${var.storage_class_name}" &>/dev/null; then
        echo "ERROR: StorageClass '${var.storage_class_name}' not found."
        exit 1
      fi

      # Annotate as cluster default
      oc annotate sc "${var.storage_class_name}" \
        storageclass.kubernetes.io/is-default-class="true" \
        --overwrite
      echo "StorageClass '${var.storage_class_name}' annotated as cluster default."
      echo "Analytics component will use ${var.analytics_volume_size} shared storage."
    EOT
  }

  depends_on = [kubernetes_namespace_v1.idig]
}

# ---------------------------------------------------------------------------
# Step 3 – Install cert-manager via OpenShift OLM
#
# 3a. Create the cert-manager-operator namespace
# 3b. Create the OperatorGroup
# 3c. Create the Subscription (triggers OLM install)
# 3d. Wait for the cert-manager webhook deployment to be Available
# ---------------------------------------------------------------------------

# 3a. cert-manager-operator namespace
resource "kubernetes_namespace_v1" "cert_manager_operator" {
  metadata {
    name = "cert-manager-operator"
    labels = {
      "app.kubernetes.io/managed-by" = "opentofu"
    }
  }
}

# 3b. OperatorGroup
resource "kubernetes_manifest" "cert_manager_operator_group" {
  manifest = {
    apiVersion = "operators.coreos.com/v1"
    kind       = "OperatorGroup"
    metadata = {
      name      = "cert-manager-operator-group"
      namespace = kubernetes_namespace_v1.cert_manager_operator.metadata[0].name
    }
    spec = {
      targetNamespaces = [
        kubernetes_namespace_v1.cert_manager_operator.metadata[0].name
      ]
    }
  }

  depends_on = [kubernetes_namespace_v1.cert_manager_operator]
}

# 3c. Subscription
resource "kubernetes_manifest" "cert_manager_subscription" {
  manifest = {
    apiVersion = "operators.coreos.com/v1alpha1"
    kind       = "Subscription"
    metadata = {
      name      = "openshift-cert-manager-operator"
      namespace = kubernetes_namespace_v1.cert_manager_operator.metadata[0].name
    }
    spec = {
      channel             = "stable-v1"
      name                = "openshift-cert-manager-operator"
      source              = "redhat-operators"
      sourceNamespace     = "openshift-marketplace"
      installPlanApproval = "Automatic"
    }
  }

  depends_on = [kubernetes_manifest.cert_manager_operator_group]
}

# 3d. Wait for cert-manager webhook to be Available
resource "null_resource" "wait_cert_manager" {
  triggers = {
    subscription = kubernetes_manifest.cert_manager_subscription.manifest["metadata"]["name"]
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      echo "Waiting for cert-manager webhook deployment..."
      for i in $(seq 1 30); do
        if oc -n cert-manager wait --for=condition=Available \
            deployment/cert-manager-webhook --timeout=30s 2>/dev/null; then
          echo "cert-manager webhook is ready."
          exit 0
        fi
        echo "  attempt $i/30 – not ready yet, sleeping 20s..."
        sleep 20
      done
      echo "ERROR: cert-manager webhook did not become ready in time."
      exit 1
    EOT
  }

  depends_on = [kubernetes_manifest.cert_manager_subscription]
}

# ---------------------------------------------------------------------------
# Step 4 – Install and configure the ingress-ca ClusterIssuer
#
# 4a. selfsigning-cluster-issuer  – self-signed bootstrap ClusterIssuer
# 4b. ingress-ca Certificate      – CA cert in cert-manager namespace
# 4c. ingress-cluster-issuer      – ClusterIssuer backed by ingress-ca
# 4d. Wait for all three to reach Ready condition
# ---------------------------------------------------------------------------

# 4a. selfsigning-cluster-issuer
resource "kubernetes_manifest" "selfsigning_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "selfsigning-cluster-issuer"
    }
    spec = {
      selfSigned = {}
    }
  }

  depends_on = [null_resource.wait_cert_manager]
}

# 4b. ingress-ca Certificate (must live in cert-manager namespace so
#     ClusterIssuers can access the resulting secret cluster-wide)
resource "kubernetes_manifest" "ingress_ca_cert" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "Certificate"
    metadata = {
      name      = "ingress-ca"
      namespace = "cert-manager"
    }
    spec = {
      isCA        = true
      commonName  = "ingress-ca"
      secretName  = "ingress-ca"
      duration    = "87600h" # 10 years
      renewBefore = "720h"   # 30 days
      privateKey = {
        rotationPolicy = "Always"
      }
      usages = [
        "digital signature",
        "key encipherment",
        "cert sign",
      ]
      issuerRef = {
        name  = "selfsigning-cluster-issuer"
        kind  = "ClusterIssuer"
        group = "cert-manager.io"
      }
    }
  }

  depends_on = [kubernetes_manifest.selfsigning_cluster_issuer]
}

# 4c. ingress-cluster-issuer
resource "kubernetes_manifest" "ingress_cluster_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "ingress-cluster-issuer"
    }
    spec = {
      ca = {
        secretName = "ingress-ca"
      }
    }
  }

  depends_on = [kubernetes_manifest.ingress_ca_cert]
}

# 4d. Wait for the full ClusterIssuer chain to be Ready
resource "null_resource" "wait_ingress_issuer" {
  triggers = {
    cert_manager = null_resource.wait_cert_manager.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"

      echo "Waiting for selfsigning-cluster-issuer to be Ready..."
      oc wait clusterissuer/selfsigning-cluster-issuer \
        --for=condition=Ready --timeout=120s

      echo "Waiting for ingress-ca Certificate to be Ready..."
      oc wait certificate/ingress-ca \
        -n cert-manager --for=condition=Ready --timeout=120s

      echo "Waiting for ingress-cluster-issuer to be Ready..."
      oc wait clusterissuer/ingress-cluster-issuer \
        --for=condition=Ready --timeout=120s

      echo "ingress-ca ClusterIssuer chain is ready."
    EOT
  }

  depends_on = [kubernetes_manifest.ingress_cluster_issuer]
}
