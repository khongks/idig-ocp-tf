##############################################################################
# 04-idig-cluster – main.tf
#
#   1. Apply the IDIG CRDs           (oc apply --server-side -f idig-crds.yaml)
#   2. Apply the IDIG cluster CR     (equivalent of samples/idig-cluster.yaml
#                                     after the documented sed replacements)
#
# The CR is built from variables rather than sed-editing the sample, because
# several fields are toggled (watsonxSecret, storage, analytics). Field names
# and defaults follow the 12.1.1.3 samples/idig-cluster.yaml.
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-deploying-idig-cluster
##############################################################################

terraform {
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
  }
}

locals {
  crds_file = "${var.release_files_path}/idig-crds.yaml"

  gateway_domain = var.nanogw_gateway_domain != "" ? var.nanogw_gateway_domain : "idig.${var.endpoint_domain}"

  spec = merge(
    {
      imagePullSecrets = [var.image_pull_secret, "ibm-entitlement-key"]
      imageRegistry    = var.docker_registry
      version          = var.idig_version
      profile          = var.idig_profile
      license = {
        accept  = true
        use     = var.license_use
        license = var.license_id
      }
      enableAnalytics = var.enable_analytics
      enableDevPortal = var.enable_dev_portal
      domain          = var.endpoint_domain
      tenantName      = var.idig_tenant_name
      groupName       = var.idig_group_name
      nanoGateway = {
        gatewayDomain = local.gateway_domain
      }
    },
    var.watsonx_secret_name != "" ? { watsonxSecret = var.watsonx_secret_name } : {},
    var.storage_class_name != "" ? { storageClassName = var.storage_class_name } : {},
    var.enable_analytics ? {
      analyticsStorage = {
        type = "shared"
        shared = {
          volumeClaimTemplate = merge(
            { volumeSize = var.analytics_volume_size },
            var.storage_class_name != "" ? { storageClassName = var.storage_class_name } : {},
          )
        }
      }
    } : {},
    var.runtime_log_level != "" ? { runtimeConfig = { logLevel = var.runtime_log_level } } : {},
  )

  idig_cluster_yaml = yamlencode({
    apiVersion = "datapowerinteractgateway.ibm.com/v1beta1"
    kind       = "DatapowerInteractGatewayCluster"
    metadata = {
      name      = var.idig_cr_name
      namespace = var.namespace
    }
    spec = local.spec
  })
}

# ---------------------------------------------------------------------------
# 1. IDIG CRDs
# ---------------------------------------------------------------------------
resource "null_resource" "idig_crds" {
  triggers = {
    crds = filesha256(local.crds_file)
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -euo pipefail
      oc apply --server-side --force-conflicts -f "${local.crds_file}"
      oc wait --for=condition=Established -f "${local.crds_file}" --timeout=120s
    EOT
  }
}

# ---------------------------------------------------------------------------
# 2. IDIG cluster CR
# ---------------------------------------------------------------------------
resource "local_file" "idig_cluster" {
  content         = local.idig_cluster_yaml
  filename        = "${path.module}/.rendered/idig-cluster.yaml"
  file_permission = "0644"
}

resource "null_resource" "idig_cluster" {
  triggers = {
    manifest_sha    = sha256(local.idig_cluster_yaml)
    operators_ready = var.operators_ready
    # Used by the destroy-time provisioner (it can only read self.triggers).
    kubeconfig = var.kubeconfig_path
    namespace  = var.namespace
    cr_name    = var.idig_cr_name
  }

  # On destroy, delete the CR while the operators still run so they can
  # process finalizers and remove Analytics/DevPortal/NanoGW. Deleting the
  # namespace first leaves orphaned CRs that resurface as an "upgrade" on the
  # next install.
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = lookup(self.triggers, "kubeconfig", "") }
    command     = <<-EOT
      set -uo pipefail
      CR="${lookup(self.triggers, "cr_name", "")}"
      NS="${lookup(self.triggers, "namespace", "")}"
      if [[ -z "$CR" || -z "$NS" || -z "$KUBECONFIG" ]]; then
        echo "Created before the destroy hook existed – delete the IDIG CR manually if needed."
        exit 0
      fi
      oc delete datapowerinteractgatewaycluster "$CR" -n "$NS" --ignore-not-found --timeout=15m
    EOT
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    environment = { KUBECONFIG = var.kubeconfig_path }
    command     = <<-EOT
      set -euo pipefail
      echo "Applying IDIG cluster CR '${var.idig_cr_name}' (profile ${var.idig_profile}, version ${var.idig_version})"
      oc apply -n "${var.namespace}" -f "${abspath(local_file.idig_cluster.filename)}"
    EOT
  }

  depends_on = [null_resource.idig_crds]
}
