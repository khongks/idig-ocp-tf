##############################################################################
# IBM DataPower Interact Gateway – OpenTofu root main.tf
# Orchestrates the 7-step OCP deployment in strict dependency order.
##############################################################################

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.12.0"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.0"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_path
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}

# ---------------------------------------------------------------------------
# Step 1 – Prerequisites: namespace, cert-manager, ingress issuer
# ---------------------------------------------------------------------------
module "prereqs" {
  source = "./01-prereqs"

  kubeconfig_path       = var.kubeconfig_path
  namespace             = var.namespace
  storage_class_name    = var.storage_class_name
  analytics_volume_size = var.analytics_volume_size
}

# ---------------------------------------------------------------------------
# Step 2 – Prepare: registry pull secrets (and optional Watsonx secret)
# ---------------------------------------------------------------------------
module "prep" {
  source = "./02-prep"

  namespace           = var.namespace
  docker_registry     = var.docker_registry
  docker_user         = var.docker_user
  docker_password     = var.docker_password
  ibm_entitlement_key = var.ibm_entitlement_key
  watsonx_api_key     = var.watsonx_api_key
  watsonx_project_id  = var.watsonx_project_id

  depends_on = [module.prereqs]
}

# ---------------------------------------------------------------------------
# Step 3 – Operators: APIC, NanoGW, Valkey, IDIG NanoGW, IDIG
# ---------------------------------------------------------------------------
module "operators" {
  source = "./03-operators"

  kubeconfig_path    = var.kubeconfig_path
  namespace          = var.namespace
  docker_registry    = var.docker_registry
  release_files_path = var.release_files_path
  valkey_certs_dir   = var.valkey_certs_dir

  depends_on = [module.prep]
}

# ---------------------------------------------------------------------------
# Step 4 – IDIG cluster CR
# ---------------------------------------------------------------------------
module "idig_cluster" {
  source = "./04-idig-cluster"

  kubeconfig_path    = var.kubeconfig_path
  namespace          = var.namespace
  endpoint_domain    = var.endpoint_domain
  docker_registry    = var.docker_registry
  idig_profile       = var.idig_profile
  idig_tenant_name   = var.idig_tenant_name
  idig_group_name    = var.idig_group_name
  storage_class_name    = var.storage_class_name
  analytics_volume_size = var.analytics_volume_size
  enable_analytics      = var.enable_analytics
  enable_dev_portal  = var.enable_dev_portal
  idig_version       = var.idig_version
  license_use        = var.license_use
  license_id         = var.license_id
  watsonx_api_key    = var.watsonx_api_key
  release_files_path = var.release_files_path
  operators_ready    = module.operators.idig_operator_ready

  depends_on = [module.operators]
}

# ---------------------------------------------------------------------------
# Step 5 – Wildcard routes on the default IngressController
# ---------------------------------------------------------------------------
module "wildcard_routes" {
  source = "./05-wildcard-routes"

  kubeconfig_path      = var.kubeconfig_path
  idig_cluster_applied = module.idig_cluster.idig_cluster_applied

  depends_on = [module.idig_cluster]
}

# ---------------------------------------------------------------------------
# Step 6 – Verification: wait for IDIG Ready phase
# ---------------------------------------------------------------------------
module "verification" {
  source = "./06-verification"

  kubeconfig_path = var.kubeconfig_path
  namespace       = var.namespace

  depends_on = [module.wildcard_routes]
}

# ---------------------------------------------------------------------------
# Step 7 – Access: retrieve admin password and platform URL
# ---------------------------------------------------------------------------
module "access" {
  source = "./07-access"

  namespace       = var.namespace
  idig_cr_name    = module.idig_cluster.idig_cr_name
  endpoint_domain = var.endpoint_domain

  depends_on = [module.verification]
}
