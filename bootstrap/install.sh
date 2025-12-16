#!/bin/bash
# Bootstrap script - installs only ArgoCD
# Everything else is managed by ArgoCD (GitOps)

set -euo pipefail

echo "=== Platform Lab Bootstrap ==="
echo ""

# Check prerequisites
if ! kubectl cluster-info &>/dev/null; then
  echo "ERROR: kubectl not connected to cluster"
  echo "Enable Kubernetes in Docker Desktop first"
  exit 1
fi

echo "Cluster: $(kubectl cluster-info | head -1)"
echo ""

# Install ArgoCD
echo "=== Installing ArgoCD ==="
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# Patch ArgoCD to allow insecure (local dev)
kubectl patch configmap argocd-cmd-params-cm -n argocd --type merge -p '{"data":{"server.insecure":"true"}}'
kubectl rollout restart deployment argocd-server -n argocd
kubectl wait --for=condition=available --timeout=120s deployment/argocd-server -n argocd

echo ""
echo "=== Bootstrap Complete ==="
echo ""
echo "ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo ""
echo "Get password:"
echo "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "Next: Update bootstrap/root-app.yaml with your GitHub repo, then:"
echo "kubectl apply -f bootstrap/root-app.yaml"
