#!/usr/bin/env bash
# Local GitOps demo: a kind cluster, Argo CD, and the two Applications from
# gitops/. Argo CD then pulls the chart from the Git repository and deploys it.
# Needs about 2 GB of free memory; remove with `make demo-down`.
set -euo pipefail

cluster=editalis-lab
argocd_version=v2.13.2

kind get clusters | grep -qx "$cluster" || kind create cluster --name "$cluster" --wait 120s
kubectl config use-context "kind-$cluster" > /dev/null

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd --server-side \
  -f "https://raw.githubusercontent.com/argoproj/argo-cd/$argocd_version/manifests/core-install.yaml"
kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=300s

# The application reads its configuration from a Secret that Git never sees.
kubectl create namespace editalis --dry-run=client -o yaml | kubectl apply -f -
kubectl -n editalis create secret generic editalis-env \
  --from-literal=DATABASE_URL="${DATABASE_URL:?set DATABASE_URL to a reachable PostgreSQL}" \
  --from-literal=ADMIN_TOKEN="$(head -c 24 /dev/urandom | base64)" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f gitops/editalis.yaml
echo "Argo CD is syncing. Watch with: kubectl -n argocd get applications -w"
