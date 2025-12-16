#!/bin/bash
# Bootstrap script - installs ArgoCD, Gateway API CRDs, and configures GitHub access
# Idempotent - safe to run multiple times

set -euo pipefail

echo "=== Platform Lab Bootstrap ==="
echo ""

# Configuration
GITHUB_REPO="https://github.com/malconip/platform-lab.git"
GITHUB_USERNAME="malconip"
GATEWAY_API_VERSION="v1.2.0"

# Check prerequisites
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl not connected to cluster"
  echo "Enable Kubernetes in Docker Desktop first"
  exit 1
fi

echo "Cluster: $(kubectl cluster-info | head -1)"
echo ""

# Check for GitHub token
if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "ERROR: GITHUB_TOKEN not set"
  echo ""
  echo "Create a Personal Access Token at:"
  echo "https://github.com/settings/tokens"
  echo ""
  echo "Required scopes: repo (full control)"
  echo ""
  echo "Then run:"
  echo "export GITHUB_TOKEN=ghp_your_token"
  echo "./bootstrap/install.sh"
  exit 1
fi

# Install Gateway API CRDs (required before NGINX Gateway Fabric)
echo "=== Installing Gateway API CRDs (${GATEWAY_API_VERSION}) ==="
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml
echo "Gateway API CRDs installed"
echo ""

# Install ArgoCD
echo "=== Installing ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Patch ArgoCD to disable TLS (local dev)
echo ""
echo "=== Configuring ArgoCD ==="
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || \
kubectl create configmap argocd-cmd-params-cm -n argocd \
  --from-literal=server.insecure=true

kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd

# Configure GitHub repository credentials
echo ""
echo "=== Configuring GitHub Repository ==="
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: platform-lab-repo
  namespace: argocd
  labels:
    argocd.argoproj.io/secret-type: repository
stringData:
  type: git
  url: ${GITHUB_REPO}
  username: ${GITHUB_USERNAME}
  password: ${GITHUB_TOKEN}
EOF

echo "GitHub repository configured"

# Apply root application
echo ""
echo "=== Deploying Root Application ==="
kubectl apply -f bootstrap/root-app.yaml

# Get admin password
echo ""
echo "=== Bootstrap Complete ==="
echo ""
ARGO_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "ArgoCD UI: http://localhost:8080"
echo "Username:  admin"
echo "Password:  ${ARGO_PASSWORD}"
echo ""
echo "=== Access Services ==="
echo ""
echo "Option 1 - Port Forward:"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:80"
echo ""
echo "Option 2 - Gateway API (after sync completes):"
echo "  http://argocd.localhost"
echo "  http://backstage.localhost"
echo "  http://grafana.localhost"
echo "  http://prometheus.localhost"
echo ""
echo "ArgoCD will now sync all platform components from GitHub!"
