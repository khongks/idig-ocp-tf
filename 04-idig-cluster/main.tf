##############################################################################
# 04-idig-cluster – main.tf
#
# Deploys the IDIG cluster Custom Resource by:
#   1. Rendering the idig-cluster.yaml.tpl template with all variables
#   2. Writing the result to templates/.rendered/idig-cluster.yaml
#   3. Applying the CR with `oc apply`
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-deploying-idig-cluster
##############################################################################

terraform {
  required_providers {
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
    }
  }
}

# ---------------------------------------------------------------------------
# Render the IDIG cluster CR template
# ---------------------------------------------------------------------------

locals {
  idig_cluster_rendered = templatefile("${path.module}/templates/idig-cluster.yaml.tpl", {
    namespace         = var.namespace
    endpoint_domain   = var.endpoint_domain
    docker_registry   = var.docker_registry
    image_pull_secret = "apic-registry-secret"
    idig_tenant_name  = var.idig_tenant_name
    idig_group_name   = var.idig_group_name
    idig_version      = var.idig_version
    idig_profile      = var.idig_profile
    enable_analytics  = var.enable_analytics
    enable_dev_portal = var.enable_dev_portal
    license_use       = var.license_use
    license_id        = var.license_id
    storage_class         = var.storage_class_name
    analytics_volume_size = var.analytics_volume_size
    watsonx_api_key       = var.watsonx_api_key
  })
}

resource "local_file" "idig_cluster_manifest" {
  content  = local.idig_cluster_rendered
  filename = "${path.module}/templates/.rendered/idig-cluster.yaml"
}

# ---------------------------------------------------------------------------
# Deploy the IDIG cluster CR
# ---------------------------------------------------------------------------
resource "null_resource" "deploy_idig_cluster" {
  triggers = {
    manifest_sha        = sha256(local.idig_cluster_rendered)
    profile             = var.idig_profile
    namespace           = var.namespace
    endpoint_domain     = var.endpoint_domain
    registry            = var.docker_registry
    tenant              = var.idig_tenant_name
    group               = var.idig_group_name
    storage_class         = var.storage_class_name
    analytics_volume_size = var.analytics_volume_size
    enable_analytics      = tostring(var.enable_analytics)
    enable_dev_portal   = tostring(var.enable_dev_portal)
    license_use         = var.license_use
    operators_ready     = var.operators_ready
  }

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = <<-EOT
      export KUBECONFIG="${var.kubeconfig_path}"
      echo "--- Applying IDIG cluster CR (profile: ${var.idig_profile}) ---"
      oc apply -f "${path.module}/templates/.rendered/idig-cluster.yaml" \
        -n "${var.namespace}"
      echo "IDIG cluster CR applied."
    EOT
  }

  depends_on = [local_file.idig_cluster_manifest]
}
