# Platform Engineering Lab

Local Kubernetes platform showcasing GitOps, Platform Engineering, and Developer Experience.

## Stack

| Component | Purpose | Namespace |
|-----------|---------|-----------|
| ArgoCD | GitOps controller | `argocd` |
| Crossplane | Infrastructure as Code | `crossplane-system` |
| Backstage | Internal Developer Portal | `backstage` |
| Prometheus + Grafana | Observability | `monitoring` |
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

```bash
# ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:80
# Open: http://localhost:8080

# Grafana
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
# Open: http://localhost:3000 (admin / platform-lab)

# Backstage
kubectl port-forward svc/backstage -n backstage 7007:7007
# Open: http://localhost:7007
```

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
│   ├── apps/              # ApplicationSet
│   ├── argocd/
│   ├── crossplane/
│   ├── backstage/
│   ├── monitoring/
│   └── sealed-secrets/
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
