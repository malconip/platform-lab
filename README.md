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
- GitHub Personal Access Token (repo scope)

### 1. Bootstrap

```bash
# Create GitHub PAT at: https://github.com/settings/tokens
# Required scopes: repo

export GITHUB_TOKEN=ghp_your_token

# Run bootstrap (idempotent - safe to run multiple times)
./bootstrap/install.sh
```

### 2. Access Services

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

## Repository Structure

```
platform-lab/
├── bootstrap/              # Manual bootstrap (ArgoCD only)
│   ├── install.sh         # Idempotent bootstrap script
│   └── root-app.yaml      # App-of-apps entrypoint
│
├── platform/              # Platform components (GitOps managed)
│   ├── apps/              # ApplicationSet definition
│   ├── argocd/           # ArgoCD self-management
│   ├── crossplane/       # Crossplane + providers + XRDs
│   ├── backstage/        # Developer portal
│   ├── monitoring/       # Prometheus, Grafana
│   └── sealed-secrets/   # Secrets management
│
├── infrastructure/        # Crossplane compositions
│   ├── compositions/     # XRDs and Compositions
│   └── claims/          # Infrastructure claims
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
- **Observability**: Prometheus, Grafana dashboards
- **Security**: Sealed Secrets, RBAC
- **CI/CD**: GitHub Actions → GHCR → ArgoCD sync
