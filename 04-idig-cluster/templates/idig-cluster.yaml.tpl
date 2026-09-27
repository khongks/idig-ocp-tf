apiVersion: datapowerinteractgateway.ibm.com/v1beta1
kind: DatapowerInteractGatewayCluster
metadata:
  name: idig
  namespace: ${namespace}
spec:
  imagePullSecrets:
    - ${image_pull_secret}
    - ibm-entitlement-key
  imageRegistry: ${docker_registry}
  version: ${idig_version}
  profile: ${idig_profile}
  # License configuration for IBM DataPower Interact Gateway
  license:
    accept: true
    use: ${license_use}  # Change to "production" for production deployments
    license: "${license_id}"

  enableAnalytics: ${enable_analytics}  # Set to true to enable Analytics
  enableDevPortal: ${enable_dev_portal}  # Set to true to enable DevPortal

  # The base domain for all endpoints in the platform
  domain: ${endpoint_domain}

  # Optional: Custom ingress certificate for IDIG Gateway HTTPRoutes (idig-api and idig-web)
  # If not specified, cert-manager will automatically generate certificates using ingress-issuer
  # The secret must be of type kubernetes.io/tls with tls.crt, tls.key, and ca.crt
  # customIngressCertificate: "idig-custom-cert"
  
  # Tenant and group configuration
  tenantName: "${idig_tenant_name}"
  groupName: "${idig_group_name}"

  # Optional: pre-created secret containing watsonx credentials.
  # If omitted, GenAI-related services are not deployed.
  %{~ if watsonx_api_key != "" ~}
  watsonxSecret: "watsonx-credentials"
  %{~ endif ~}

  # Storage configuration (optional)
  # Global storage class for all subsystems
  # If not specified, uses cluster default storage class
  storageClassName: "${storage_class}"
  
  # Analytics-specific storage configuration (optional)
  # If not specified, defaults to 200Gi for shared storage
  analyticsStorage:
    type: shared
    shared:
      volumeClaimTemplate:
        storageClassName: "${storage_class}"  # Overrides global storageClassName
        volumeSize: "${analytics_volume_size}"

  # Analytics-specific settings (optional)
  # Configure analytics client authentication for the ingestion endpoint (ai.<domain>)
  # analyticsSettings:
  #   clientSubjectDN: "CN=analytics-ingestion-client,O=cert-manager"  # Expected client certificate subject DN for mTLS authentication (RFC 2253 format)

  # NanoGateway configuration is handled by the profile template
  # To customize NanoGateway settings, patch the NanoGatewayCluster CR after creation
  nanoGateway:
    gatewayDomain: nanogw.${endpoint_domain}
