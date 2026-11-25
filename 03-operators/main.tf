##############################################################################
# 03-operators – main.tf
#
# Installs the operators in the documented order, rendering manifests directly
# from the release bundle (var.release_files_path):
#   1. API Connect operator     dependencies/ibm-apiconnect-crds.yaml, ibm-apiconnect.yaml
#   2. NanoGateway CRDs         dependencies/ibm-nanogw-crds.yaml
#   3. Valkey                   dependencies/valkey-crds.yaml, valkey-operator.yaml,
#                               valkey-extra-config.yaml, valkey_standalone_cr.yaml
#   4. IDIG NanoGateway operator  ibm-idig-nanogw.yaml
#   5. IDIG operator              ibm-idig-operator.yaml
#
# Placeholders (REPLACE-NAMESPACE, REPLACE-DOCKER-REGISTRY,
# DEFAULT_IMAGE_PULL_SECRET, REPLACE-STORAGE-CLASS) are substituted by
# scripts/render-apply.sh into .rendered/ – the bundle is never modified.
# Each step re-applies when its source file or inputs change.
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-installing-operators
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
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

locals {
  rel = var.release_files_path
  dep = "${var.release_files_path}/dependencies"

  render = "bash '${abspath(path.module)}/scripts/render-apply.sh'"

  # Environment shared by every local-exec in this module.
  env = {
    KUBECONFIG    = var.kubeconfig_path
    NAMESPACE     = var.namespace
    REGISTRY      = var.docker_registry
    PULL_SECRET   = var.image_pull_secret
    STORAGE_CLASS = var.storage_class_name
    RENDER_DIR    = "${abspath(path.module)}/.rendered"
  }

  # Inputs that change every rendered manifest.
  render_inputs = sha256(jsonencode([var.namespace, var.docker_registry, var.image_pull_secret]))
}

# ---------------------------------------------------------------------------
# 1. API Connect operator
# ---------------------------------------------------------------------------
resource "null_resource" "apic_operator" {
  triggers = {
    crds     = filesha256("${local.dep}/ibm-apiconnect-crds.yaml")
    operator = filesha256("${local.dep}/ibm-apiconnect.yaml")
    inputs   = local.render_inputs
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      oc apply --server-side --force-conflicts -f "${local.dep}/ibm-apiconnect-crds.yaml"
      ${local.render} "${local.dep}/ibm-apiconnect.yaml"
      oc -n "$NAMESPACE" wait --for=condition=Available deployment/ibm-apiconnect --timeout=600s
    EOT
  }
}

# ---------------------------------------------------------------------------
# 2. NanoGateway CRDs (cluster-scoped)
# ---------------------------------------------------------------------------
resource "null_resource" "nanogw_crds" {
  triggers = {
    crds = filesha256("${local.dep}/ibm-nanogw-crds.yaml")
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      oc apply --server-side --force-conflicts -f "${local.dep}/ibm-nanogw-crds.yaml"
      oc wait --for=condition=Established -f "${local.dep}/ibm-nanogw-crds.yaml" --timeout=120s
    EOT
  }

  depends_on = [null_resource.apic_operator]
}

# ---------------------------------------------------------------------------
# 3. Valkey
# ---------------------------------------------------------------------------

# 3a. TLS – generated here instead of the openssl commands in the docs
#     (same CN/SANs). Rotated automatically on apply within early_renewal_hours.
resource "tls_private_key" "valkey_ca" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "valkey_ca" {
  private_key_pem       = tls_private_key.valkey_ca.private_key_pem
  is_ca_certificate     = true
  validity_period_hours = var.valkey_cert_validity_hours
  early_renewal_hours   = 720
  allowed_uses          = ["cert_signing", "crl_signing", "digital_signature"]

  subject {
    common_name = "ValkeyCA"
  }
}

resource "tls_private_key" "valkey" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "valkey" {
  private_key_pem = tls_private_key.valkey.private_key_pem
  dns_names = [
    "valkey.${var.namespace}.svc.cluster.local",
    "valkey.${var.namespace}.svc",
  ]

  subject {
    common_name = "valkey.${var.namespace}.svc.cluster.local"
  }
}

resource "tls_locally_signed_cert" "valkey" {
  cert_request_pem      = tls_cert_request.valkey.cert_request_pem
  ca_private_key_pem    = tls_private_key.valkey_ca.private_key_pem
  ca_cert_pem           = tls_self_signed_cert.valkey_ca.cert_pem
  validity_period_hours = var.valkey_cert_validity_hours
  early_renewal_hours   = 720
  # The probes also present this cert as a client cert, so allow both.
  allowed_uses = ["digital_signature", "key_encipherment", "server_auth", "client_auth"]
}

resource "kubernetes_secret_v1" "valkey_tls" {
  metadata {
    name      = "valkey-tls"
    namespace = var.namespace
  }
  data = {
    "ca.crt"  = tls_self_signed_cert.valkey_ca.cert_pem
    "tls.crt" = tls_locally_signed_cert.valkey.cert_pem
    "tls.key" = tls_private_key.valkey.private_key_pem_pkcs8
  }
}

# 3b. Credentials – the docs' sample password "admin" is a placeholder.
#     No special characters: the Valkey probes pass it unquoted to valkey-cli.
resource "random_password" "valkey" {
  length  = 24
  special = false
}

resource "kubernetes_secret_v1" "valkey_secret" {
  metadata {
    name      = "valkey-secret"
    namespace = var.namespace
  }
  data = {
    username = "default"
    password = random_password.valkey.result
  }
}

# 3c. CRDs + operator
resource "null_resource" "valkey_operator" {
  triggers = {
    crds     = filesha256("${local.dep}/valkey-crds.yaml")
    operator = filesha256("${local.dep}/valkey-operator.yaml")
    inputs   = local.render_inputs
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      oc apply --server-side --force-conflicts -f "${local.dep}/valkey-crds.yaml"
      ${local.render} "${local.dep}/valkey-operator.yaml" --server-side --force-conflicts
      oc -n "$NAMESPACE" wait --for=condition=Available deployment/valkey-operator --timeout=300s
    EOT
  }

  depends_on = [null_resource.nanogw_crds]
}

# 3d. Module config + standalone instance
#     On OCP the docs' fsGroup=1000 patch is NOT applied (restricted SCC
#     assigns it). An empty storage_class_name drops storageClassName so the
#     PVC uses the cluster default.
resource "null_resource" "valkey_instance" {
  triggers = {
    extra_config  = filesha256("${local.dep}/valkey-extra-config.yaml")
    instance      = filesha256("${local.dep}/valkey_standalone_cr.yaml")
    inputs        = local.render_inputs
    storage_class = var.storage_class_name
    tls           = sha256(tls_locally_signed_cert.valkey.cert_pem)
    password      = sha256(random_password.valkey.result)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      ${local.render} "${local.dep}/valkey-extra-config.yaml"
      ${local.render} "${local.dep}/valkey_standalone_cr.yaml"
      echo "Waiting for the Valkey pod..."
      for i in $(seq 1 30); do
        oc -n "$NAMESPACE" get pod -l app.kubernetes.io/name=valkey -o name 2>/dev/null | grep -q . && break
        sleep 10
      done
      oc -n "$NAMESPACE" wait --for=condition=Ready pod -l app.kubernetes.io/name=valkey --timeout=600s
    EOT
  }

  depends_on = [
    null_resource.valkey_operator,
    kubernetes_secret_v1.valkey_tls,
    kubernetes_secret_v1.valkey_secret,
  ]
}

# ---------------------------------------------------------------------------
# 4. IDIG NanoGateway operator
# ---------------------------------------------------------------------------
resource "null_resource" "idig_nanogw_operator" {
  triggers = {
    operator = filesha256("${local.rel}/ibm-idig-nanogw.yaml")
    inputs   = local.render_inputs
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      ${local.render} "${local.rel}/ibm-idig-nanogw.yaml"
      oc -n "$NAMESPACE" wait --for=condition=Available deployment/idig-gw-operator --timeout=300s
    EOT
  }

  depends_on = [null_resource.valkey_instance]
}

# ---------------------------------------------------------------------------
# 5. IDIG operator
# ---------------------------------------------------------------------------
resource "null_resource" "idig_operator" {
  triggers = {
    operator = filesha256("${local.rel}/ibm-idig-operator.yaml")
    inputs   = local.render_inputs
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = local.env
    command     = <<-EOT
      set -euo pipefail
      ${local.render} "${local.rel}/ibm-idig-operator.yaml"
      oc -n "$NAMESPACE" wait --for=condition=Available deployment/idig-operator --timeout=600s
    EOT
  }

  depends_on = [null_resource.idig_nanogw_operator]
}
