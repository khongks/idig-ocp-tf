---
# Source: valkey/templates/valkey-standalone.yaml
apiVersion: valkey.datapower.ibm.com/v1beta2
kind: Valkey
metadata:
  name:  valkey
  namespace: ${namespace}
  labels:
    app.kubernetes.io/name: valkey
    helm.sh/chart: valkey-1.0.0
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/instance: valkey
    app.kubernetes.io/version: 1.0.0
    app.kubernetes.io/component: middleware
  annotations:
    
spec:
  kubernetesConfig:
    image: "${docker_registry}/valkey:8.1.4"
    imagePullPolicy: "Always"
    imagePullSecrets: 
    - name: ${image_pull_secret}
    valkeySecret:
      name: "valkey-secret"
      key: "password"
    persistentVolumeClaimRetentionPolicy: 
      whenDeleted: Delete
      whenScaled: Retain
  TLS:
    ca: "ca.crt"
    cert: "tls.crt"
    key: "tls.key"
    secret:
      secretName: "valkey-tls"
    clientCert: "tls.crt"
    clientKey: "tls.key"
    clientSecret:
      secretName: "valkey-client-tls"
