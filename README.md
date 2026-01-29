# Platform Engineering Lab

Local Kubernetes platform showcasing GitOps, Platform Engineering, and Developer Experience.

## Stack

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| ArgoCD | GitOps controller | `argocd` |
| NGINX Gateway Fabric | Gateway API controller | `nginx-gateway` |
| Crossplane | Infrastructure as Code | `crossplane-system` |
| Backstage | Internal Developer Portal | `backstage` |
| Prometheus + Grafana + AlertManager | Observability | `monitoring` |
| Sealed Secrets | GitOps-friendly secrets | `kube-system` |

## Quick Start

### Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl
- GitHub Personal Access Token (repo scope)

### 1. Bootstrap

```bash
# Create GitHub PAT at: https://github.com/settings/tokens
# Required scopes: repo

export GITHUB_TOKEN=ghp_your_token
./bootstrap/install.sh
```

### 2. Wait for Core Components

```bash
# Check all apps are synced
kubectl get apps -n argocd

# Wait for Crossplane to be ready
kubectl wait --for=condition=available --timeout=300s deployment/crossplane -n crossplane-system

# Wait for Gateway to be ready
kubectl get gateway -n nginx-gateway
```

### 3. Install Crossplane Providers (manual step)

```bash
kubectl apply -f platform/crossplane/providers.yaml

# Wait for providers to be healthy
kubectl get providers
```

### 4. Install Crossplane XRDs (manual step)

```bash
kubectl apply -f infrastructure/compositions/
```

### 5. Access Services

**Option A: Gateway API (recommended)**

```bash
# Get the Gateway LoadBalancer IP (Docker Desktop uses localhost)
kubectl get svc -n nginx-gateway

# Add to /etc/hosts (if needed)
# 127.0.0.1 argocd.localhost backstage.localhost grafana.localhost prometheus.localhost alertmanager.localhost

# Access via:
# http://argocd.localhost
# http://backstage.localhost
# http://grafana.localhost (admin / platform-lab)
# http://prometheus.localhost
# http://alertmanager.localhost
```

**Option B: Port Forwarding**

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Open: http://localhost:8080

# Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Open: http://localhost:3000 (admin / platform-lab)

# Backstage
kubectl port-forward svc/backstage-helm -n backstage 7007:7007
# Open: http://localhost:7007
```

**Option C: kubefwd (forward all services)**

```bash
brew install txn2/tap/kubefwd
sudo kubefwd svc -n backstage -n argocd -n monitoring -n nginx-gateway
# Access by service name: http://backstage-helm:7007
```

## Gateway API Architecture

This lab uses the modern **Gateway API** instead of the deprecated Ingress API:

```
                    ┌──────────────────────────────────────┐
                    │         Gateway API CRDs             │
                    │   (GatewayClass, Gateway, HTTPRoute) │
                    └──────────────────────────────────────┘
                                      │
                    ┌─────────────────▼─────────────────┐
                    │      NGINX Gateway Fabric         │
                    │    (Gateway API Controller)       │
                    └─────────────────┬─────────────────┘
                                      │
    ┌────────────┬────────────┬────────────┼────────────┬────────────┐
    ▼            ▼            ▼            ▼            ▼            ▼
┌────────┐ ┌──────────┐ ┌─────────┐ ┌────────────┐ ┌────────────┐
│ argocd │ │backstage │ │ grafana │ │ prometheus │ │alertmanager│
│  :80   │ │  :7007   │ │   :80   │ │   :9090    │ │   :9093    │
└────────┘ └──────────┘ └─────────┘ └────────────┘ └────────────┘
```

### Why Gateway API?

- **Ingress NGINX is deprecated** (EOL March 2026)
- **Gateway API is the future** - standardized, multi-protocol, role-based
- **Better separation of concerns** - Platform team manages Gateway, App teams manage HTTPRoutes
- **Native support for gRPC, TCP, UDP** - not just HTTP

## Create an App with Crossplane

```bash
kubectl apply -f infrastructure/claims/demo-webapp.yaml

# Check the created resources
kubectl get webapps
kubectl get ns | grep app-
```

## Repository Structure

```
platform-lab/
├── bootstrap/              # Manual bootstrap
│   ├── install.sh         # Idempotent bootstrap script
│   └── root-app.yaml      # App-of-apps entrypoint
│
├── platform/              # ArgoCD managed
│   ├── apps/              # ApplicationSet + standalone apps
│   ├── argocd/            # Self-managed ArgoCD
│   ├── gateway-api/       # NGINX Gateway Fabric + routes
│   ├── crossplane/        # Crossplane + providers
│   ├── backstage/         # PostgreSQL infrastructure
│   ├── monitoring/        # Prometheus + Grafana + AlertManager
│   └── sealed-secrets/    # Sealed Secrets controller
│
├── infrastructure/        # Manual after Crossplane ready
│   ├── compositions/      # XRDs and Compositions
│   └── claims/           # Example claims
│
└── templates/            # Backstage templates
```

## Known Limitations (Docker Desktop)

- **node-exporter disabled** - doesn't work with Docker Desktop mount system
- **No persistent volumes by default** - data lost on restart
- **LoadBalancer uses localhost** - Docker Desktop maps LoadBalancer to 127.0.0.1

## ArgoCD Credentials

```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```
