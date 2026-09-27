##############################################################################
# 03-operators – main.tf
#
# Installs the five operators in the required order:
#   1. API Connect (APIC) operator  – ibm-apiconnect-crds.yaml + ibm-apiconnect.yaml
#   2. NanoGateway operator         – ibm-nanogw-crds.yaml + ibm-nanogw.yaml
#   3. Valkey operator + instance   – valkey-crds.yaml + valkey-operator.yaml +
#                                     valkey_standalone_cr.yaml
#   4. IDIG NanoGateway operator    – ibm-idig-nanogw.yaml
#   5. IDIG operator                – ibm-idig-operator.yaml
#
# All YAML files originate from the product release bundle under:
#   <release_files_path>/dependencies/
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-installing-operators
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

locals {
  dep_dir = "${var.release_files_path}/dependencies"
  kc      = var.kubeconfig_path
  ns      = var.namespace
  reg     = var.docker_registry
}

# ---------------------------------------------------------------------------
# OPERATOR 1 – API Connect (APIC)
# ---------------------------------------------------------------------------

# 1a. Apply APIC CRDs (server-side to avoid annotation-too-long errors)
resource "null_resource" "apply_apic_crds" {
  triggers = {
    crds_file = "03-operators/dependencies/ibm-apiconnect-crds.yaml"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply --server-side --force-conflicts \
        -f "03-operators/dependencies/ibm-apiconnect-crds.yaml" \
        -n "${local.ns}"
      echo "APIC CRDs applied."
    EOT
  }
}

# 1b. Render ibm-apiconnect.yaml template and write to a local file
locals {
  apic_operator_rendered = templatefile("${path.module}/templates/ibm-apiconnect.yaml.tpl", {
    docker_registry   = local.reg
    namespace         = local.ns
    image_pull_secret = "apic-registry-secret"
  })
}

resource "local_file" "apic_operator_manifest" {
  content  = local.apic_operator_rendered
  filename = "${path.module}/templates/.rendered/ibm-apiconnect.yaml"
}

# 1c. Deploy the rendered APIC operator manifest
resource "null_resource" "deploy_apic_operator" {
  triggers = {
    manifest_sha = sha256(local.apic_operator_rendered)
    namespace    = local.ns
    registry     = local.reg
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply -f "${path.module}/templates/.rendered/ibm-apiconnect.yaml" \
        -n "${local.ns}"
      echo "APIC operator applied."
    EOT
  }

  depends_on = [
    null_resource.apply_apic_crds,
    local_file.apic_operator_manifest,
  ]
}

# 1d. Wait for APIC operator deployment to become Available
resource "null_resource" "wait_apic_operator" {
  triggers = {
    deploy = null_resource.deploy_apic_operator.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc -n "${local.ns}" wait --for=condition=Available \
        deployment/ibm-apiconnect --timeout=300s
      echo "APIC operator is Available."
    EOT
  }

  depends_on = [null_resource.deploy_apic_operator]
}

# ---------------------------------------------------------------------------
# OPERATOR 2 – NanoGateway
# ---------------------------------------------------------------------------

# 2a. Apply NanoGateway CRDs
resource "null_resource" "apply_nanogw_crds" {
  triggers = {
    crds_file = "03-operators/dependencies/ibm-nanogw-crds.yaml"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply --server-side --force-conflicts \
        -f "03-operators/dependencies/ibm-nanogw-crds.yaml"
      echo "NanoGateway CRDs applied."
    EOT
  }

  depends_on = [null_resource.wait_apic_operator]
}

# 2b. Render ibm-nanogw.yaml template and write to a local file
locals {
  nanogw_operator_rendered = templatefile("${path.module}/templates/ibm-nanogw.yaml.tpl", {
    namespace         = local.ns
    image_pull_secret = "ibm-entitlement-key"
  })
}

resource "local_file" "nanogw_operator_manifest" {
  content  = local.nanogw_operator_rendered
  filename = "${path.module}/templates/.rendered/ibm-nanogw.yaml"
}

# 2c. Deploy the rendered NanoGateway operator manifest
resource "null_resource" "deploy_nanogw_operator" {
  triggers = {
    manifest_sha = sha256(local.nanogw_operator_rendered)
    namespace    = local.ns
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply -f "${path.module}/templates/.rendered/ibm-nanogw.yaml" \
        -n "${local.ns}"
      echo "NanoGateway operator applied."
    EOT
  }

  depends_on = [
    null_resource.apply_nanogw_crds,
    local_file.nanogw_operator_manifest,
  ]
}

# ---------------------------------------------------------------------------
# OPERATOR 3 – Valkey (Redis-compatible cache)
# ---------------------------------------------------------------------------

# 3a. Generate Valkey TLS certificates via openssl
#     Certs are written to var.valkey_certs_dir (default: ./certs).
#     Skipped if ca.crt already exists (idempotent).
resource "null_resource" "generate_valkey_certs" {
  triggers = {
    certs_dir = var.valkey_certs_dir
    namespace = local.ns
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      CERTS_DIR="${var.valkey_certs_dir}"
      NS="${local.ns}"

      if [ -f "$CERTS_DIR/ca.crt" ]; then
        echo "Valkey certs already exist in $CERTS_DIR – skipping generation."
        exit 0
      fi

      mkdir -p "$CERTS_DIR"

      # CA key and self-signed certificate
      openssl genrsa -out "$CERTS_DIR/ca.key" 2048
      openssl req -x509 -new -nodes \
        -key "$CERTS_DIR/ca.key" -sha256 -days 365 \
        -out "$CERTS_DIR/ca.crt" \
        -subj "/CN=ValkeyCA"

      # Server key and CSR
      openssl genrsa -out "$CERTS_DIR/tls.key" 2048
      openssl req -new \
        -key "$CERTS_DIR/tls.key" \
        -out "$CERTS_DIR/tls.csr" \
        -subj "/CN=valkey.$NS.svc.cluster.local"

      # SAN config
      cat > "$CERTS_DIR/san.cnf" <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name

[req_distinguished_name]

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = valkey.$NS.svc.cluster.local
DNS.2 = valkey.$NS.svc
EOF

      # Server certificate with SAN
      openssl x509 -req \
        -in  "$CERTS_DIR/tls.csr" \
        -CA  "$CERTS_DIR/ca.crt" \
        -CAkey "$CERTS_DIR/ca.key" \
        -CAcreateserial \
        -out "$CERTS_DIR/tls.crt" \
        -days 365 -sha256 \
        -extfile "$CERTS_DIR/san.cnf" \
        -extensions v3_req

      echo "Valkey certs generated in $CERTS_DIR."
    EOT
  }
}

# 3b. Create Valkey TLS secret from generated certs
resource "null_resource" "valkey_tls" {
  triggers = {
    certs_dir = var.valkey_certs_dir
    namespace = local.ns
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc create secret generic valkey-tls \
        --from-file=ca.crt="${var.valkey_certs_dir}/ca.crt" \
        --from-file=tls.crt="${var.valkey_certs_dir}/tls.crt" \
        --from-file=tls.key="${var.valkey_certs_dir}/tls.key" \
        -n "${local.ns}" \
        --dry-run=client -o yaml | oc apply -f -
      echo "valkey-tls secret applied."
    EOT
  }

  depends_on = [null_resource.generate_valkey_certs]
}

# 3c. Create Valkey credentials secret
resource "kubernetes_secret_v1" "valkey_secret" {
  metadata {
    name      = "valkey-secret"
    namespace = local.ns
  }

  type = "Opaque"

  data = {
    username = "default"
    password = "admin"
  }
}

# 3d. Apply Valkey CRDs
resource "null_resource" "apply_valkey_crds" {
  triggers = {
    crds_file = "03-operators/dependencies/valkey-crds.yaml"
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply --server-side --force-conflicts \
        -f "03-operators/dependencies/valkey-crds.yaml"
      echo "Valkey CRDs applied."
    EOT
  }

  depends_on = [null_resource.deploy_nanogw_operator]
}

# 3e. Render valkey-operator.yaml template and write to a local file
locals {
  valkey_operator_rendered = templatefile("${path.module}/templates/valkey-operator.yaml.tpl", {
    docker_registry   = local.reg
    namespace         = local.ns
    image_pull_secret = "apic-registry-secret"
  })
}

resource "local_file" "valkey_operator_manifest" {
  content  = local.valkey_operator_rendered
  filename = "${path.module}/templates/.rendered/valkey-operator.yaml"
}

# 3f. Deploy the rendered Valkey operator manifest
resource "null_resource" "deploy_valkey_operator" {
  triggers = {
    manifest_sha = sha256(local.valkey_operator_rendered)
    namespace    = local.ns
    registry     = local.reg
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply --server-side --force-conflicts \
        -f "${path.module}/templates/.rendered/valkey-operator.yaml" \
        -n "${local.ns}"
      echo "Valkey operator applied."
    EOT
  }

  depends_on = [
    null_resource.apply_valkey_crds,
    local_file.valkey_operator_manifest,
  ]
}

# 3g. Wait for Valkey operator
resource "null_resource" "wait_valkey_operator" {
  triggers = {
    deploy = null_resource.deploy_valkey_operator.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc -n "${local.ns}" wait --for=condition=Available \
        deployment/valkey-operator --timeout=180s
      echo "Valkey operator is Available."
    EOT
  }

  depends_on = [null_resource.deploy_valkey_operator]
}

# 3h. Render valkey_standalone_cr.yaml template and write to a local file
locals {
  valkey_instance_rendered = templatefile("${path.module}/templates/valkey_standalone_cr.yaml.tpl", {
    docker_registry   = local.reg
    namespace         = local.ns
    image_pull_secret = "apic-registry-secret"
  })
}

resource "local_file" "valkey_instance_manifest" {
  content  = local.valkey_instance_rendered
  filename = "${path.module}/templates/.rendered/valkey_standalone_cr.yaml"
}

# 3i. Deploy the rendered Valkey instance CR
resource "null_resource" "deploy_valkey_instance" {
  triggers = {
    manifest_sha = sha256(local.valkey_instance_rendered)
    namespace    = local.ns
    registry     = local.reg
    certs_dir    = var.valkey_certs_dir
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply -f "${path.module}/templates/.rendered/valkey_standalone_cr.yaml" \
        -n "${local.ns}"
      echo "Valkey instance CR applied."
    EOT
  }

  depends_on = [
    null_resource.wait_valkey_operator,
    null_resource.valkey_tls,
    kubernetes_secret_v1.valkey_secret,
    local_file.valkey_instance_manifest,
  ]
}

# 3j. Wait for Valkey instance pods to be ready
resource "null_resource" "wait_valkey_instance" {
  triggers = {
    instance = null_resource.deploy_valkey_instance.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      echo "Sleeping 30s for Valkey operator to create pods..."
      sleep 30
      oc -n "${local.ns}" wait --for=condition=ready pod \
        -l app.kubernetes.io/name=valkey --timeout=300s
      echo "Valkey instance pods are ready."
    EOT
  }

  depends_on = [null_resource.deploy_valkey_instance]
}

# ---------------------------------------------------------------------------
# OPERATOR 4 – IDIG NanoGateway operator
# ---------------------------------------------------------------------------

# 4a. Render ibm-idig-nanogw.yaml template and write to a local file
locals {
  idig_nanogw_operator_rendered = templatefile("${path.module}/templates/ibm-idig-nanogw.yaml.tpl", {
    docker_registry   = local.reg
    namespace         = local.ns
    image_pull_secret = "apic-registry-secret"
  })
}

resource "local_file" "idig_nanogw_operator_manifest" {
  content  = local.idig_nanogw_operator_rendered
  filename = "${path.module}/templates/.rendered/ibm-idig-nanogw.yaml"
}

# 4b. Deploy the rendered IDIG NanoGateway operator manifest
resource "null_resource" "deploy_idig_nanogw_operator" {
  triggers = {
    manifest_sha = sha256(local.idig_nanogw_operator_rendered)
    namespace    = local.ns
    registry     = local.reg
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply -f "${path.module}/templates/.rendered/ibm-idig-nanogw.yaml" \
        -n "${local.ns}"
      echo "IDIG NanoGateway operator applied."
    EOT
  }

  depends_on = [
    null_resource.wait_valkey_instance,
    local_file.idig_nanogw_operator_manifest,
  ]
}

# 4c. Wait for IDIG NanoGateway operator to become Available
resource "null_resource" "wait_idig_nanogw_operator" {
  triggers = {
    deploy = null_resource.deploy_idig_nanogw_operator.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc -n "${local.ns}" wait --for=condition=Available \
        deployment/idig-gw-operator --timeout=120s
      echo "IDIG NanoGateway operator is Available."
    EOT
  }

  depends_on = [null_resource.deploy_idig_nanogw_operator]
}

# ---------------------------------------------------------------------------
# OPERATOR 5 – IDIG operator
# ---------------------------------------------------------------------------

# 5a. Render ibm-idig-operator.yaml template and write to a local file
locals {
  idig_operator_rendered = templatefile("${path.module}/templates/ibm-idig-operator.yaml.tpl", {
    docker_registry   = local.reg
    namespace         = local.ns
    image_pull_secret = "apic-registry-secret"
  })
}

resource "local_file" "idig_operator_manifest" {
  content  = local.idig_operator_rendered
  filename = "${path.module}/templates/.rendered/ibm-idig-operator.yaml"
}

# 5b. Deploy the rendered IDIG operator manifest
resource "null_resource" "deploy_idig_operator" {
  triggers = {
    manifest_sha = sha256(local.idig_operator_rendered)
    namespace    = local.ns
    registry     = local.reg
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc apply -f "${path.module}/templates/.rendered/ibm-idig-operator.yaml" \
        -n "${local.ns}"
      echo "IDIG operator applied."
    EOT
  }

  depends_on = [
    null_resource.wait_idig_nanogw_operator,
    local_file.idig_operator_manifest,
  ]
}

# 5c. Wait for IDIG operator to become Available
resource "null_resource" "wait_idig_operator" {
  triggers = {
    deploy = null_resource.deploy_idig_operator.id
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${local.kc}"
      oc -n "${local.ns}" wait --for=condition=Available \
        deployment/idig-operator --timeout=120s
      echo "IDIG operator is Available."
    EOT
  }

  depends_on = [null_resource.deploy_idig_operator]
}
