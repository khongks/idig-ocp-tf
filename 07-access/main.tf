##############################################################################
# 07-access – main.tf
#
# Computes the platform UI URL and the oc command to retrieve the admin
# password after a successful IDIG deployment.
#
# Route hostnames follow the pattern set by the IDIG operators:
#   Platform UI:     idig.<endpoint_domain>
#   Developer Portal: devportal.<endpoint_domain>
#
# Admin password secret: <idig_cr_name>-idig-admin-pass
#
# Doc reference:
#   https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-verifying-installation-accessing-idig
##############################################################################

terraform {
  required_providers {}
}

locals {
  idig_platform_url      = "https://idig.${var.endpoint_domain}"
  idig_devportal_url     = "https://devportal.${var.endpoint_domain}"
  admin_password_cmd     = "oc get secret ${var.idig_cr_name}-idig-admin-pass -n ${var.namespace} -o jsonpath='{.data.password}' | base64 -d && echo"
  devportal_password_cmd = "oc get secret ${var.idig_cr_name}-devportal-admin-secret -n ${var.namespace} -o jsonpath='{.data.password}' | base64 -d && echo"
}
