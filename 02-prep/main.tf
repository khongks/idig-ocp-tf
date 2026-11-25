##############################################################################
# 02-prep – main.tf
#
#   • apic-registry-secret  – pull secret for the target registry (IDIG images)
#   • ibm-entitlement-key   – pull secret for cp.icr.io/cp/datapower
#   • watsonx-credentials   – optional, enables the GenAI service
#
# Equivalent to:
#   oc create secret docker-registry apic-registry-secret --docker-server=$REGISTRY ...
#   oc create secret docker-registry ibm-entitlement-key --docker-server=cp.icr.io/cp/datapower --docker-username=cp ...
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-preparing-deployment-environment
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
  watsonx_enabled = var.watsonx_api_key != ""

  dockerconfig = {
    apic = jsonencode({
      auths = {
        (var.docker_registry) = {
          username = var.docker_user
          password = var.docker_password
          auth     = base64encode("${var.docker_user}:${var.docker_password}")
        }
      }
    })
    icr = jsonencode({
      auths = {
        # Docs use cp.icr.io/cp/datapower; the host-only key also covers it.
        "cp.icr.io" = {
          username = "cp"
          password = var.ibm_entitlement_key
          auth     = base64encode("cp:${var.ibm_entitlement_key}")
        }
      }
    })
  }
}

resource "kubernetes_secret_v1" "apic_registry_secret" {
  metadata {
    name      = "apic-registry-secret"
    namespace = var.namespace
  }
  type = "kubernetes.io/dockerconfigjson"
  data = { ".dockerconfigjson" = local.dockerconfig.apic }
}

resource "kubernetes_secret_v1" "ibm_entitlement_key" {
  metadata {
    name      = "ibm-entitlement-key"
    namespace = var.namespace
  }
  type = "kubernetes.io/dockerconfigjson"
  data = { ".dockerconfigjson" = local.dockerconfig.icr }
}

resource "kubernetes_secret_v1" "watsonx_credentials" {
  count = local.watsonx_enabled ? 1 : 0

  metadata {
    name      = "watsonx-credentials"
    namespace = var.namespace
  }
  type = "Opaque"
  data = {
    WATSONX_API_KEY    = var.watsonx_api_key
    WATSONX_PROJECT_ID = var.watsonx_project_id
  }

  lifecycle {
    precondition {
      condition     = var.watsonx_project_id != ""
      error_message = "watsonx_project_id is required when watsonx_api_key is set."
    }
  }
}
