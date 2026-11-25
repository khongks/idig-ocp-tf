##############################################################################
# IBM DataPower Interact Gateway (IDIG) 12.1.1.x on OpenShift – root module
#
# Runs steps 01–07 in order. Images must already be in var.docker_registry
# (see 00-load-images, which is run separately).
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=deploying-openshift
##############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.4.0"
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

# The kubernetes provider and every `oc` call use the kubeconfig's current context.
provider "kubernetes" {
  config_path = var.kubeconfig_path
}

# ---------------------------------------------------------------------------
# 01 – Namespace, default StorageClass check, cert-manager (OLM), ingress-issuer
# ---------------------------------------------------------------------------
module "prereqs" {
  source = "./01-prereqs"

  kubeconfig_path           = var.kubeconfig_path
  namespace                 = var.namespace
  release_files_path        = var.release_files_path
  storage_class_name        = var.storage_class_name
  set_default_storage_class = var.set_default_storage_class
  install_cert_manager      = var.install_cert_manager
  enable_analytics          = var.enable_analytics
  configure_max_map_count   = var.configure_max_map_count
}

# ---------------------------------------------------------------------------
# 02 – Pull secrets and optional WatsonX secret
# ---------------------------------------------------------------------------
module "prep" {
  source = "./02-prep"

  namespace           = module.prereqs.namespace_name
  docker_registry     = var.docker_registry
  docker_user         = var.docker_user
  docker_password     = var.docker_password
  ibm_entitlement_key = var.ibm_entitlement_key
  watsonx_api_key     = var.watsonx_api_key
  watsonx_project_id  = var.watsonx_project_id

  depends_on = [module.prereqs]
}

# ---------------------------------------------------------------------------
# 03 – APIC operator, NanoGW CRDs, Valkey, IDIG NanoGW operator, IDIG operator
# ---------------------------------------------------------------------------
module "operators" {
  source = "./03-operators"

  kubeconfig_path    = var.kubeconfig_path
  namespace          = var.namespace
  docker_registry    = var.docker_registry
  image_pull_secret  = module.prep.image_pull_secret
  release_files_path = var.release_files_path
  storage_class_name = var.storage_class_name

  depends_on = [module.prep]
}

# ---------------------------------------------------------------------------
# 04 – IDIG CRDs and cluster CR
# ---------------------------------------------------------------------------
module "idig_cluster" {
  source = "./04-idig-cluster"

  kubeconfig_path       = var.kubeconfig_path
  namespace             = var.namespace
  release_files_path    = var.release_files_path
  idig_cr_name          = var.idig_cr_name
  endpoint_domain       = var.endpoint_domain
  nanogw_gateway_domain = var.nanogw_gateway_domain
  docker_registry       = var.docker_registry
  image_pull_secret     = module.prep.image_pull_secret
  idig_version          = var.idig_version
  idig_profile          = var.idig_profile
  idig_tenant_name      = var.idig_tenant_name
  idig_group_name       = var.idig_group_name
  storage_class_name    = var.storage_class_name
  analytics_volume_size = var.analytics_volume_size
  enable_analytics      = var.enable_analytics
  enable_dev_portal     = var.enable_dev_portal
  license_use           = var.license_use
  license_id            = var.license_id
  watsonx_secret_name   = module.prep.watsonx_secret_name
  runtime_log_level     = var.runtime_log_level
  operators_ready       = module.operators.idig_operator_ready
}

# ---------------------------------------------------------------------------
# 05 – Wildcard routes on the default IngressController (cluster-wide)
# ---------------------------------------------------------------------------
module "wildcard_routes" {
  source = "./05-wildcard-routes"

  kubeconfig_path        = var.kubeconfig_path
  enable_wildcard_routes = var.enable_wildcard_routes

  depends_on = [module.idig_cluster]
}

# ---------------------------------------------------------------------------
# 06 – Wait for Ready and check routes
# ---------------------------------------------------------------------------
module "verification" {
  source = "./06-verification"

  kubeconfig_path      = var.kubeconfig_path
  namespace            = var.namespace
  idig_cr_name         = module.idig_cluster.idig_cr_name
  idig_cluster_applied = module.idig_cluster.idig_cluster_applied

  depends_on = [module.wildcard_routes]
}

# ---------------------------------------------------------------------------
# 07 – Access details
# ---------------------------------------------------------------------------
module "access" {
  source = "./07-access"

  namespace         = var.namespace
  idig_cr_name      = module.idig_cluster.idig_cr_name
  endpoint_domain   = var.endpoint_domain
  enable_dev_portal = var.enable_dev_portal

  depends_on = [module.verification]
}
