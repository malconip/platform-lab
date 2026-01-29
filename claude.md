# Platform Lab - Claude Context Specification

## Overview

Local Kubernetes platform demonstrating GitOps, Platform Engineering, and Developer Experience patterns. Runs on Docker Desktop Kubernetes.

**Key Technologies:** ArgoCD (GitOps), Crossplane (Infrastructure as Code), Backstage (IDP), Gateway API (routing), kube-prometheus-stack (observability)

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              GITOPS FLOW                                     │
│                                                                              │
│   bootstrap/install.sh                                                       │
│         │                                                                    │
│         ▼                                                                    │
│   ┌─────────────┐    watches    ┌────────────────────┐                       │
│   │ root-app    │──────────────▶│ platform/apps/     │                       │
│   │ (ArgoCD)    │               │ platform-apps.yaml │                       │
│   └─────────────┘               └────────────────────┘                       │
│                                          │                                   │
│                            ┌─────────────┼─────────────┐                     │
│                            ▼             ▼             ▼                     │
│                    ApplicationSet   Standalone    Standalone                 │
│                    (5 components)   (crossplane)  (backstage)                │
│                            │                                                 │
│         ┌──────────────────┼──────────────────┬───────────────┐              │
│         ▼                  ▼                  ▼               ▼              │
│   platform/argocd   platform/monitoring   platform/gateway-api   ...        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
platform-lab/
├── bootstrap/                    # ONE-TIME SETUP (run manually)
│   ├── install.sh               # Installs ArgoCD, Gateway API CRDs, configures GitHub
│   └── root-app.yaml            # App-of-apps entry point
│
├── platform/                     # ARGOCD MANAGED (GitOps - auto-synced)
│   ├── apps/
│   │   └── platform-apps.yaml   # ApplicationSet + standalone apps definition
│   ├── argocd/                  # ArgoCD self-management config
│   ├── backstage/               # Backstage + PostgreSQL
│   ├── crossplane/              # Crossplane namespace + providers config
│   ├── gateway-api/             # NGINX Gateway Fabric + HTTPRoutes
│   ├── monitoring/              # kube-prometheus-stack (Prometheus, Grafana, AlertManager)
│   └── sealed-secrets/          # Sealed Secrets controller
│
├── infrastructure/               # MANUAL APPLY (after Crossplane ready)
│   ├── compositions/            # Crossplane XRDs and Compositions
│   │   ├── webapp-xrd.yaml      # WebApp custom resource definition
│   │   └── webapp-composition.yaml  # How WebApp creates K8s resources
│   └── claims/                  # Example infrastructure claims
│       └── demo-webapp.yaml     # Example: creates namespace + deployment + service
│
└── templates/                    # BACKSTAGE TEMPLATES
    └── webapp-template.yaml     # Self-service template for creating WebApps
```

---

## How It Works

### Bootstrap (One-Time)

```bash
export GITHUB_TOKEN=ghp_xxx
./bootstrap/install.sh
```

This script:
1. Installs Gateway API CRDs
2. Installs NGINX Gateway Fabric CRDs
3. Installs ArgoCD
4. Configures GitHub repo credentials
5. Deploys `root-app.yaml` which watches `platform/apps/`

### GitOps Flow

1. **root-app** watches `platform/apps/platform-apps.yaml`
2. **platform-apps.yaml** contains:
   - `AppProject` named "platform"
   - `ApplicationSet` that generates apps from a list (argocd, sealed-secrets, monitoring, backstage-infra, gateway-api)
   - Standalone `Application` for Crossplane (Helm chart)
   - Standalone `Application` for Backstage (Helm chart)
3. Each generated app watches its `platform/<name>/` directory
4. Changes to git → ArgoCD syncs automatically

### Component Types

| Type | Location | How ArgoCD Handles |
|------|----------|-------------------|
| **Kustomize** | `platform/<name>/kustomization.yaml` | Reads kustomization.yaml, applies resources |
| **Helm (inline)** | `platform/apps/platform-apps.yaml` | Application spec contains Helm values |
| **Helm (external)** | `platform/monitoring/helm-release.yaml` | Application pointing to Helm repo |

---

## Adding New Components

### Option 1: Add to ApplicationSet (Kustomize-based)

For new platform components managed by Kustomize:

1. Create directory: `platform/<new-component>/`
2. Add files:
   ```
   platform/new-component/
   ├── kustomization.yaml    # Required
   ├── namespace.yaml        # If needs dedicated namespace
   └── *.yaml                # Your manifests
   ```

3. Add to ApplicationSet in `platform/apps/platform-apps.yaml`:
   ```yaml
   generators:
     - list:
         elements:
           # ... existing ...
           - name: new-component
             namespace: new-namespace
             path: platform/new-component
   ```

4. Commit and push → ArgoCD syncs automatically

### Option 2: Standalone Application (Helm chart)

For components installed via external Helm charts:

Add to `platform/apps/platform-apps.yaml`:
```yaml
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-helm-app
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://charts.example.com
    chart: my-chart
    targetRevision: 1.0.0
    helm:
      values: |
        key: value
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### Option 3: Mixed (Helm release in Kustomize)

For Helm charts that need additional resources:

1. Create `platform/new-component/helm-release.yaml` (ArgoCD Application pointing to Helm)
2. Create `platform/new-component/kustomization.yaml` referencing it
3. Add any additional manifests (ConfigMaps, Secrets, etc.)
4. Add to ApplicationSet

---

## Adding New Applications (Developer Self-Service)

### Via Crossplane Claim

Developers create a `WebApp` claim to get a full application:

```yaml
# infrastructure/claims/my-app.yaml
apiVersion: platform.local/v1alpha1
kind: WebApp
metadata:
  name: my-app
  namespace: default
spec:
  name: my-app
  image: nginx:alpine
  replicas: 2
  port: 80
  env: dev
```

**What Crossplane creates:**
- Namespace: `app-my-app`
- Deployment with specified image/replicas
- Service (ClusterIP)

**Apply manually:**
```bash
kubectl apply -f infrastructure/claims/my-app.yaml
```

### Via Backstage (UI)

Users can create apps through Backstage UI using `templates/webapp-template.yaml` which:
1. Prompts for name, image, replicas, port, env
2. Creates the Crossplane claim
3. Registers in Backstage catalog

---

## Adding HTTPRoutes (Exposing Services)

To expose a service via Gateway API:

Edit `platform/gateway-api/routes.yaml`:
```yaml
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-service-route
  namespace: my-namespace           # Where the service lives
spec:
  parentRefs:
    - name: platform-gateway
      namespace: nginx-gateway
  hostnames:
    - "my-service.localhost"        # Add to /etc/hosts: 127.0.0.1 my-service.localhost
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: my-service          # Service name
          port: 80                  # Service port
```

Commit and push → ArgoCD syncs → Route active

---

## Modifying Existing Components

### Change Helm Values

Edit the `helm.values` section in the respective Application:

- **Monitoring:** `platform/monitoring/helm-release.yaml`
- **Crossplane:** `platform/apps/platform-apps.yaml` (crossplane Application)
- **Backstage:** `platform/apps/platform-apps.yaml` (backstage Application)

### Change Kustomize Resources

Edit files in `platform/<component>/` and update `kustomization.yaml` if adding new files.

### Change ArgoCD Sync Behavior

Edit Application specs in `platform/apps/platform-apps.yaml`:
- `syncPolicy.automated` - Enable/disable auto-sync
- `syncOptions` - Add options like `ServerSideApply=true`

---

## Crossplane: Creating New Resource Types

### 1. Define XRD (Custom Resource Definition)

```yaml
# infrastructure/compositions/myresource-xrd.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: CompositeResourceDefinition
metadata:
  name: xmyresources.platform.local
spec:
  group: platform.local
  names:
    kind: XMyResource
    plural: xmyresources
  claimNames:
    kind: MyResource
    plural: myresources
  versions:
    - name: v1alpha1
      served: true
      referenceable: true
      schema:
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              required: [name]
              properties:
                name:
                  type: string
                # Add your properties
```

### 2. Define Composition (What Gets Created)

```yaml
# infrastructure/compositions/myresource-composition.yaml
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: myresource-kubernetes
spec:
  compositeTypeRef:
    apiVersion: platform.local/v1alpha1
    kind: XMyResource
  resources:
    - name: some-resource
      base:
        apiVersion: kubernetes.crossplane.io/v1alpha2
        kind: Object
        spec:
          forProvider:
            manifest:
              # Your K8s manifest here
      patches:
        - type: FromCompositeFieldPath
          fromFieldPath: spec.name
          toFieldPath: spec.forProvider.manifest.metadata.name
```

### 3. Apply (Manual Step)

```bash
kubectl apply -f infrastructure/compositions/
```

### 4. Create Claim

```yaml
apiVersion: platform.local/v1alpha1
kind: MyResource
metadata:
  name: example
spec:
  name: example
```

---

## Service Access

### URLs (Gateway API)

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | http://argocd.localhost | admin / (see command below) |
| Backstage | http://backstage.localhost | - |
| Grafana | http://grafana.localhost | admin / platform-lab |
| Prometheus | http://prometheus.localhost | - |
| AlertManager | http://alertmanager.localhost | - |

**Required /etc/hosts:**
```
127.0.0.1 argocd.localhost backstage.localhost grafana.localhost prometheus.localhost alertmanager.localhost
```

### Get ArgoCD Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

---

## Useful Commands

### ArgoCD

```bash
# List all apps
kubectl get apps -n argocd

# Check app status
kubectl get app <name> -n argocd -o yaml

# Force sync
kubectl patch app <name> -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'

# Get app health
kubectl get apps -n argocd -o custom-columns=NAME:.metadata.name,HEALTH:.status.health.status,SYNC:.status.sync.status
```

### Crossplane

```bash
# Check providers
kubectl get providers

# Check XRDs
kubectl get xrd

# Check compositions
kubectl get compositions

# Check claims
kubectl get webapps -A

# Debug claim
kubectl describe webapp <name>
```

### Gateway API

```bash
# Check gateway
kubectl get gateway -n nginx-gateway

# Check routes
kubectl get httproute -A

# Check gateway controller
kubectl get pods -n nginx-gateway
```

### Monitoring

```bash
# Check Prometheus targets
kubectl port-forward svc/kube-prometheus-stack-prometheus -n monitoring 9090:9090
# Open http://localhost:9090/targets

# Check AlertManager
kubectl port-forward svc/kube-prometheus-stack-alertmanager -n monitoring 9093:9093
# Open http://localhost:9093
```

---

## Known Limitations (Docker Desktop)

| Issue | Reason | Impact |
|-------|--------|--------|
| node-exporter disabled | Docker Desktop mount restrictions | Some metrics unavailable |
| Control plane alerts firing | kube-scheduler, controller-manager, etcd not exposed | Expected, ignore |
| No persistent volumes by default | Docker Desktop limitation | Data lost on restart |
| LoadBalancer = localhost | Docker Desktop maps to 127.0.0.1 | Use Gateway API or port-forward |

### Expected Alerts (Not Real Problems)

- `KubeProxyDown`, `KubeSchedulerDown`, `KubeControllerManagerDown`
- `etcdMembersDown`, `etcdInsufficientMembers`
- `TargetDown` for control plane components
- `KubePodCrashLooping` for node-exporter

---

## Quick Reference: File Patterns

### Kustomize Component

```yaml
# platform/my-component/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
```

### Helm Application (in platform-apps.yaml)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-app
  namespace: argocd
spec:
  project: platform
  source:
    repoURL: https://charts.example.com
    chart: my-chart
    targetRevision: "1.0.0"
    helm:
      values: |
        key: value
  destination:
    server: https://kubernetes.default.svc
    namespace: my-namespace
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### HTTPRoute

```yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: my-route
  namespace: target-namespace
spec:
  parentRefs:
    - name: platform-gateway
      namespace: nginx-gateway
  hostnames:
    - "my-service.localhost"
  rules:
    - backendRefs:
        - name: my-service
          port: 80
```

### Crossplane Claim

```yaml
apiVersion: platform.local/v1alpha1
kind: WebApp
metadata:
  name: my-app
  namespace: default
spec:
  name: my-app
  image: nginx:alpine
  replicas: 1
  port: 80
  env: dev
```

---

## Deployment Checklist

### Adding New Platform Component

- [ ] Create `platform/<name>/` directory
- [ ] Add `kustomization.yaml`
- [ ] Add to ApplicationSet in `platform/apps/platform-apps.yaml`
- [ ] Add HTTPRoute to `platform/gateway-api/routes.yaml` if needs external access
- [ ] Commit and push
- [ ] Verify in ArgoCD UI

### Adding New Application (via Crossplane)

- [ ] Ensure Crossplane providers are healthy: `kubectl get providers`
- [ ] Ensure XRDs are installed: `kubectl get xrd`
- [ ] Create claim YAML in `infrastructure/claims/`
- [ ] Apply: `kubectl apply -f infrastructure/claims/<name>.yaml`
- [ ] Check status: `kubectl get webapps`

### Modifying Existing Component

- [ ] Edit files in `platform/<component>/`
- [ ] If adding new files, update `kustomization.yaml`
- [ ] Commit and push
- [ ] ArgoCD auto-syncs (or force sync if needed)
