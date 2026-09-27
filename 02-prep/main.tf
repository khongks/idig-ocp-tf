##############################################################################
# 02-prep – main.tf
#
# Implements:
#   • apic-registry-secret  – Docker pull secret for the target registry
#   • ibm-entitlement-key   – Docker pull secret for cp.icr.io/cp/datapower
#   • watsonx-credentials   – Optional secret for GenAI / WatsonX features
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-preparing-deployment-environment
##############################################################################

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.27.0"
    }
  }
}

locals {
  # Build .dockerconfigjson value for apic-registry-secret
  apic_docker_auth = base64encode("${var.docker_user}:${var.docker_password}")
  apic_docker_config = jsonencode({
    auths = {
      (var.docker_registry) = {
        username = var.docker_user
        password = var.docker_password
        auth     = local.apic_docker_auth
      }
    }
  })

  # Build .dockerconfigjson value for ibm-entitlement-key
  icr_auth = base64encode("cp:${var.ibm_entitlement_key}")
  icr_docker_config = jsonencode({
    auths = {
      "cp.icr.io" = {
        username = "cp"
        password = var.ibm_entitlement_key
        auth     = local.icr_auth
      }
    }
  })
}

# ---------------------------------------------------------------------------
# apic-registry-secret – pull secret for the customer's target registry
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "apic_registry_secret" {
  metadata {
    name      = "apic-registry-secret"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.apic_docker_config
  }
}

# ---------------------------------------------------------------------------
# ibm-entitlement-key – pull secret for IBM Container Registry (NanoGateway)
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "ibm_entitlement_key" {
  metadata {
    name      = "ibm-entitlement-key"
    namespace = var.namespace
  }

  type = "kubernetes.io/dockerconfigjson"

  data = {
    ".dockerconfigjson" = local.icr_docker_config
  }
}

# ---------------------------------------------------------------------------
# watsonx-credentials – optional secret for GenAI service
# Created only when var.watsonx_api_key is non-empty.
# ---------------------------------------------------------------------------
resource "kubernetes_secret_v1" "watsonx_credentials" {
  count = var.watsonx_api_key != "" ? 1 : 0

  metadata {
    name      = "watsonx-credentials"
    namespace = var.namespace
  }

  type = "Opaque"

  data = {
    WATSONX_API_KEY    = var.watsonx_api_key
    WATSONX_PROJECT_ID = var.watsonx_project_id
  }
}
