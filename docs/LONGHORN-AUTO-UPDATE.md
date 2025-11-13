# Longhorn Auto-Update Guide

## 🤖 How Longhorn Updates Are Automated

### **Current Setup: Renovate Bot**

Your cluster uses **Renovate Bot** to automatically detect and propose Longhorn updates via Pull Requests.

**How it works:**
1. 🔍 **Renovate scans** `argocd-apps/longhorn.yaml` every weekend
2. 📦 **Detects new versions** from the Longhorn Helm repository
3. 🔀 **Creates a PR** with the update (one minor version at a time)
4. 👀 **You review** the PR and verify it's safe to upgrade
5. ✅ **Merge the PR** to trigger the upgrade
6. 🚀 **ArgoCD auto-syncs** and applies the new version

---

## ⚠️ Why Phased Upgrades Are Required

**Longhorn enforces strict upgrade rules:**

> ✅ **Allowed**: v1.7.x → v1.8.x → v1.9.x → v1.10.x  
> ❌ **Not Allowed**: v1.7.x → v1.10.x (skipping versions)

**Reasons:**
- **Data migration safety** - Each version may have schema changes
- **Engine compatibility** - Volume engines need gradual updates
- **Settings migration** - New settings are introduced incrementally
- **Rollback safety** - Easier to identify which upgrade caused issues

---

## 📋 Automated Update Workflow

### **Step 1: Renovate Creates PR**

Every weekend, Renovate checks for new Longhorn versions and creates a PR like:

```
⚠️ [Longhorn] Update longhorn to v1.11.0
```

The PR will include:
- ⚠️ Warning about phased upgrade requirement
- 📝 Current version vs. proposed version
- ✅ Upgrade instructions
- 🔍 Verification commands

### **Step 2: Review the PR**

**Before merging, check:**

1. **Verify upgrade path is valid** (only one minor version jump)
   ```bash
   # Check current version
   helm list -n longhorn-system
   
   # If current is v1.10.x and PR proposes v1.11.x → ✅ Safe
   # If current is v1.10.x and PR proposes v1.12.x → ❌ Skip a version first
   ```

2. **Check volume health**
   ```bash
   kubectl get volumes -n longhorn-system -o json | \
     jq -r '.items | group_by(.status.state) | map({state: .[0].status.state, count: length})'
   ```

3. **Verify no faulted volumes**
   ```bash
   kubectl get volumes -n longhorn-system -o json | \
     jq -r '.items[] | select(.status.state == "faulted") | .metadata.name'
   ```

### **Step 3: Merge the PR**

Once verified, merge the PR. ArgoCD will automatically:
1. Detect the change in Git
2. Sync the Longhorn Application
3. Upgrade Longhorn to the new version

### **Step 4: Verify After Upgrade**

```bash
# Check Longhorn version
helm list -n longhorn-system

# Verify volumes are healthy
kubectl get volumes -n longhorn-system

# Verify media pods are running
kubectl get pods -n media
```

---

## 🔧 Manual Upgrade (If Needed)

If you need to upgrade manually (e.g., Renovate is behind):

```bash
# 1. Backup configuration
mkdir -p /tmp/longhorn-backup-$(date +%Y%m%d)
kubectl get settings -n longhorn-system -o yaml > /tmp/longhorn-backup-$(date +%Y%m%d)/settings.yaml
kubectl get volumes -n longhorn-system -o yaml > /tmp/longhorn-backup-$(date +%Y%m%d)/volumes.yaml

# 2. Check current version
helm list -n longhorn-system

# 3. Upgrade to NEXT minor version only
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version <NEXT_MINOR_VERSION> \
  --set defaultSettings.backupTarget="s3://k8s-backups@us-east-1/" \
  --set defaultSettings.backupTargetCredentialSecret="minio-credentials" \
  --set persistence.defaultClass=true \
  --set service.ui.type=LoadBalancer \
  --set service.ui.port=80 \
  --wait \
  --timeout 10m

# 4. Verify upgrade
kubectl rollout status daemonset/longhorn-manager -n longhorn-system
kubectl get volumes -n longhorn-system
kubectl get pods -n media

# 5. Update Git to match
# Edit argocd-apps/longhorn.yaml and change targetRevision to the new version
git add argocd-apps/longhorn.yaml
git commit -m "chore(longhorn): upgrade to v<VERSION>"
git push
```

---

## 📊 Monitoring Renovate

### **Check Renovate Status**

```bash
# View Renovate logs
kubectl logs -n renovate -l app.kubernetes.io/name=renovate --tail=100 -f

# Check for pending PRs
# Go to: https://github.com/pablodelarco/kubernetes-homelab/pulls
```

### **Force Renovate to Run Now**

```bash
# Trigger immediate scan (instead of waiting for weekend)
kubectl delete job -n renovate -l app.kubernetes.io/name=renovate
```

---

## 🎯 Configuration

### **Renovate Settings for Longhorn**

Located in `renovate.json`:

```json
{
  "description": "Longhorn: Require manual approval for ALL updates",
  "matchPackageNames": ["longhorn"],
  "automerge": false,
  "separateMinorPatch": true,
  "labels": ["longhorn", "requires-manual-upgrade"]
}
```

**Key settings:**
- ✅ `automerge: false` - Never auto-merge (requires manual review)
- ✅ `separateMinorPatch: true` - Create separate PRs for minor vs patch
- ✅ `labels: ["longhorn"]` - Easy to find Longhorn PRs

---

## 🚨 Troubleshooting

### **Renovate not creating PRs**

1. Check Renovate is running:
   ```bash
   kubectl get cronjob -n renovate
   kubectl get jobs -n renovate
   ```

2. Check Renovate logs for errors:
   ```bash
   kubectl logs -n renovate -l app.kubernetes.io/name=renovate --tail=200
   ```

3. Verify GitHub token is valid:
   ```bash
   kubectl get secret -n renovate renovate-github-token
   ```

### **Upgrade failed**

1. Check Longhorn manager logs:
   ```bash
   kubectl logs -n longhorn-system -l app=longhorn-manager --tail=100
   ```

2. Restore from backup:
   ```bash
   kubectl apply -f /tmp/longhorn-backup-<DATE>/settings.yaml
   ```

3. Rollback Helm release:
   ```bash
   helm rollback longhorn -n longhorn-system
   ```

---

## 📚 Resources

- [Longhorn Upgrade Documentation](https://longhorn.io/docs/latest/deploy/upgrade/)
- [Renovate Documentation](https://docs.renovatebot.com/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

