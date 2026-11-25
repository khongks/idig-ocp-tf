##############################################################################
# 07-access – main.tf
#
# Access details for the IDIG Console and Developer Portal (user: administrator).
#   Console:    https://idig.<endpoint_domain>       secret <cr>-idig-admin-pass
#   DevPortal:  https://devportal.<endpoint_domain>  secret <cr>-devportal-admin-secret
#
# Doc: https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-verifying-installation-accessing-idig
##############################################################################

locals {
  password_cmd = "oc get secret %s -n ${var.namespace} -o jsonpath='{.data.password}' | base64 -d; echo"
}
