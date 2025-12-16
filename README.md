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

## Architecture

```
Bootstrap (manual)
     │
     └── ArgoCD
            │
            ├── ArgoCD (self-managed)
            ├── Crossplane + Providers
            ├── Backstage
            ├── Monitoring Stack
            ├── Sealed Secrets
            └── Applications
```

## Quick Start

### Prerequisites

- Docker Desktop with Kubernetes enabled
- kubectl
- kubeseal CLI
- GitHub account

### 1. Bootstrap ArgoCD

```bash
# Run bootstrap script
./bootstrap/install.sh

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 2. Connect to GitHub

Update `bootstrap/root-app.yaml` with your repo URL, then:

```bash
kubectl apply -f bootstrap/root-app.yaml
```

ArgoCD now manages everything else!

### 3. Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| ArgoCD | https://localhost:8080 | admin / (see above) |
| Backstage | http://localhost:7007 | - |
| Grafana | http://localhost:3000 | admin / prom-operator |

## Repository Structure

```
platform-lab/
├── bootstrap/              # Manual bootstrap (ArgoCD only)
│   ├── install.sh
│   └── root-app.yaml      # App-of-apps entrypoint
│
├── platform/              # Platform components (GitOps managed)
│   ├── argocd/           # ArgoCD self-management
│   ├── crossplane/       # Crossplane + providers + XRDs
│   ├── backstage/        # Developer portal
│   ├── monitoring/       # Prometheus, Grafana, Loki
│   └── sealed-secrets/   # Secrets management
│
├── infrastructure/        # Crossplane compositions
│   ├── compositions/     # XRDs and Compositions
│   └── claims/          # Infrastructure claims
│
├── apps/                 # Application deployments
│   ├── base/            # Kustomize base
│   └── overlays/        # dev, staging overlays
│
├── templates/            # Backstage scaffolder templates
│
└── .github/
    └── workflows/        # CI for images
```

## Showcased Skills

- **GitOps**: ArgoCD app-of-apps, self-managed, auto-sync
- **Platform Engineering**: Crossplane XRDs, Compositions, Claims
- **Developer Experience**: Backstage catalog, templates, TechDocs
- **Observability**: Prometheus, Grafana dashboards, Loki logs
- **Security**: Sealed Secrets, RBAC
- **CI/CD**: GitHub Actions → GHCR → ArgoCD sync
