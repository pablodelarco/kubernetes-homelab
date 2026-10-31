#!/bin/sh
# ArgoCD itself is installed from the upstream manifests (not managed by an
# Argo Application), so its node placement is applied with this patch.
# Re-run after every ArgoCD upgrade/re-install.
# 2026-10-31: all ArgoCD workloads run on worker to take load (and heat) off
# beelink. If worker is down, ArgoCD is down too; apps keep running.
# Rollback: set the hostname below to beelink and re-run.
set -eu
NODE="${1:-worker}"
PATCH="{\"spec\":{\"template\":{\"spec\":{\"nodeSelector\":{\"kubernetes.io/hostname\":\"${NODE}\"}}}}}"
for r in deploy/argocd-redis deploy/argocd-repo-server deploy/argocd-dex-server \
         deploy/argocd-applicationset-controller deploy/argocd-notifications-controller \
         deploy/argocd-image-updater deploy/argocd-server sts/argocd-application-controller; do
  kubectl -n argocd patch "$r" --type merge -p "$PATCH"
  kubectl -n argocd rollout status "$r" --timeout=300s
done
