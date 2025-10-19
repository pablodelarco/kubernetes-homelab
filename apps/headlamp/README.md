# Headlamp - Kubernetes Web UI

Headlamp is a user-friendly Kubernetes web UI focused on extensibility.

## Deployment

Deployed via ArgoCD using Helm chart from: https://headlamp-k8s.github.io/headlamp/

## Files

- `custom-values.yaml` - Helm chart values
- `ingress-tailscale.yaml` - Tailscale Funnel ingress for public access
- `serviceaccount-token.yaml` - Admin service account and token for authentication

## Access

**URL:** https://headlamp.tabby-carp.ts.net

**Authentication:** Token-based (OIDC disabled)

### Get Admin Token

```bash
kubectl get secret -n kube-system headlamp-admin-token \
  -o jsonpath='{.data.token}' | base64 -d
```

## Configuration

- **Mode:** In-cluster
- **RBAC:** Cluster-admin access
- **Authentication:** Token-based (no OIDC)
- **Ingress:** Tailscale Funnel (publicly accessible)
- **Resources:** 100m CPU / 128Mi RAM (requests), 200m CPU / 256Mi RAM (limits)

## Manual Steps After Deployment

1. Apply the Tailscale ingress:
   ```bash
   kubectl apply -f apps/headlamp/ingress-tailscale.yaml
   ```

2. Apply the service account token (if not already exists):
   ```bash
   kubectl apply -f apps/headlamp/serviceaccount-token.yaml
   ```

3. Get the admin token and save it securely:
   ```bash
   kubectl get secret -n kube-system headlamp-admin-token \
     -o jsonpath='{.data.token}' | base64 -d
   ```

## Notes

- The token never expires
- Store the token in a password manager
- The Helm chart creates its own ServiceAccount with cluster-admin access
- The `headlamp-admin` ServiceAccount is separate and used for token-based login

