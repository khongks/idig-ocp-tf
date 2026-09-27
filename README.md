# IBM DataPower Interact Gateway – OpenTofu Deployment

Automated OpenTofu module for deploying **IBM DataPower Interact Gateway (IDIG) 12.1.1**
on OpenShift Container Platform (OCP), following the official documentation at  
https://www.ibm.com/docs/en/dp-interact-gateway/12.1.1?topic=openshift-deploying

---

## Prerequisites

| Requirement | Notes |
|---|---|
| OpenShift 4.14 – 4.19 | `oc` configured and pointing to target cluster |
| Cluster-admin permissions | Required for CRDs, ClusterRoles, IngressController patch |
| OpenTofu ≥ 1.6 | `tofu` binary on your PATH |
| IDIG release bundle | Extracted locally; set `release_files_path` |
| IBM Entitlement Key | From https://myibm.ibm.com/products-services/containerlibrary |
| Target container registry | IDIG images uploaded per *Obtaining product files* docs |
| `openssl` on PATH | Used internally by OCP tooling |

---

## Directory structure

```
.
├── main.tf                   # Root orchestration – calls all 7 modules in order
├── variables.tf              # All input variables
├── outputs.tf                # Final outputs (URL, password command)
├── terraform.tfvars.example  # Example values – copy to terraform.tfvars
│
├── 01-prereqs/               # Namespace, cert-manager OLM, ingress-ca issuer
├── 02-prep/                  # Registry pull secrets + optional Watsonx secret
├── 03-operators/             # APIC, NanoGW, Valkey, IDIG NanoGW, IDIG operators
├── 04-idig-cluster/          # IDIG cluster Custom Resource (dev or prod profile)
├── 05-wildcard-routes/       # Patch IngressController → WildcardsAllowed
├── 06-verification/          # Wait for IDIG Ready phase; list pods & routes
└── 07-access/                # Output platform URL + admin password command
```

---

## Quick start

```bash
# 1. Copy and fill in your values
cp terraform.tfvars.example terraform.tfvars
$EDITOR terraform.tfvars

# 2. Initialise providers
tofu init

# 3. Preview the plan
tofu plan

# 4. Apply
tofu apply
```

After a successful apply (≈20–30 minutes on a fresh cluster):

```bash
# Retrieve admin password
$(tofu output -raw idig_admin_password_command)

# Open platform UI
echo $(tofu output -raw idig_platform_url)
```

---

## Module breakdown

### 01-prereqs
- Creates the IDIG Kubernetes namespace.
- Installs **cert-manager** via OpenShift OLM (cert-manager Operator for Red Hat OpenShift, `stable-v1` channel).
- Applies `helper_files/ingress-issuer-v1.yaml` to create the `ingress-issuer` self-signed CA.
- Optionally annotates an existing StorageClass as the cluster default.

### 02-prep
- Creates `apic-registry-secret` for the target container registry.
- Creates `ibm-entitlement-key` for `cp.icr.io/cp/datapower`.
- Optionally creates `watsonx-credentials` when `watsonx_api_key` is provided.

### 03-operators
Installs the five operators **in strict dependency order**:

| Order | Operator | Source files |
|---|---|---|
| 1 | API Connect (APIC) | `dependencies/ibm-apiconnect-crds.yaml`, `ibm-apiconnect.yaml` |
| 2 | NanoGateway | `dependencies/ibm-nanogw-crds.yaml`, `ibm-nanogw.yaml` |
| 3 | Valkey | `dependencies/valkey-crds.yaml`, `valkey-operator.yaml`, `valkey_standalone_cr.yaml` |
| 4 | IDIG NanoGateway | `ibm-idig-nanogw.yaml` |
| 5 | IDIG | `ibm-idig-operator.yaml` |

TLS certificates for Valkey are generated via the OpenTofu `tls` provider.

### 04-idig-cluster
- Selects `samples/idig-cluster-dev.yaml` or `samples/idig-cluster-prod.yaml`.
- Patches all placeholders and applies the IDIG cluster CR.

### 05-wildcard-routes
- Patches `ingresscontroller/default` in `openshift-ingress-operator` namespace to set  
  `spec.routeAdmission.wildcardPolicy: WildcardsAllowed`.  
  ⚠️ This is a **cluster-wide** change. Consult your cluster administrator.

### 06-verification
- Polls the IDIG CR status every 30 seconds until `phase == Ready` (timeout 20 min).
- Prints pod status, routes, and NanoGateway wildcard route admission status.

### 07-access
- Outputs the platform UI URL and the `oc` command to retrieve the admin password.

---

## Variables reference

| Variable | Default | Description |
|---|---|---|
| `kubeconfig_path` | — | Path to OCP kubeconfig |
| `namespace` | `idig-system` | Namespace for IDIG |
| `endpoint_domain` | — | `apps.<cluster>.<domain>` |
| `docker_registry` | — | Target image registry URL |
| `docker_user` | — | Registry username |
| `docker_password` | — | Registry password (sensitive) |
| `ibm_entitlement_key` | — | IBM Entitlement Key (sensitive) |
| `release_files_path` | — | Local path to IDIG release bundle |
| `idig_profile` | `dev` | `dev` or `prod` |
| `idig_tenant_name` | `acme` | Tenant name in IDIG CR |
| `idig_group_name` | `sandbox` | Group name in IDIG CR |
| `storage_class_name` | `""` | StorageClass (empty = cluster default) |
| `enable_analytics` | `true` | Deploy Analytics |
| `enable_dev_portal` | `true` | Deploy Developer Portal |
| `license_use` | `nonproduction` | `nonproduction` or `production` |
| `watsonx_api_key` | `""` | WatsonX API key (optional) |
| `watsonx_project_id` | `""` | WatsonX Project ID (optional) |

---

## Notes

- The `idig-cluster-dev.yaml` / `idig-cluster-prod.yaml` files are patched in-place in a
  temp file; the originals in the release bundle are never modified.
- Placeholder replacement exactly mirrors the `sed` commands from the IBM documentation.
- Sensitive variables (`docker_password`, `ibm_entitlement_key`, `watsonx_api_key`) should
  be supplied via `TF_VAR_*` environment variables or a secrets manager in CI/CD pipelines.
