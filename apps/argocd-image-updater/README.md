# ArgoCD Image Updater

Automatically updates Helm chart versions and container images in your ArgoCD applications.

## 🎯 What It Does

ArgoCD Image Updater monitors your applications and:
- ✅ Detects new Helm chart versions
- ✅ Detects new container image tags
- ✅ Automatically updates `targetRevision` in ArgoCD Application manifests
- ✅ Commits changes back to Git
- ✅ ArgoCD auto-syncs the updated applications

## 📦 How It Works

1. **Image Updater** scans your ArgoCD Applications every 2 minutes
2. Checks for new versions based on annotations
3. Updates the Git repository with new versions
4. ArgoCD detects the change and syncs automatically

## 🔧 Enabling Auto-Updates for Applications

### For Helm Charts

Add annotations to your ArgoCD Application manifest:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: homepage
  namespace: argocd
  annotations:
    # Enable image updater
    argocd-image-updater.argoproj.io/image-list: homepage=ghcr.io/gethomepage/homepage
    
    # Update strategy: semver (semantic versioning)
    argocd-image-updater.argoproj.io/homepage.update-strategy: semver
    
    # Allow updates to minor and patch versions (e.g., 2.x.x)
    argocd-image-updater.argoproj.io/homepage.allow-tags: regexp:^2\\.
    
    # Write changes back to Git
    argocd-image-updater.argoproj.io/write-back-method: git:secret:argocd/git-creds
spec:
  # ... rest of your application spec
```

### For Helm Chart Versions

To auto-update Helm chart versions (like headlamp 0.37.0):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: headlamp
  namespace: argocd
  annotations:
    # Enable Helm chart updates
    argocd-image-updater.argoproj.io/helm.image-name: headlamp
    argocd-image-updater.argoproj.io/helm.image-tag: targetRevision
    argocd-image-updater.argoproj.io/update-strategy: semver
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  sources:
    - repoURL: 'https://headlamp-k8s.github.io/headlamp/'
      chart: headlamp
      targetRevision: 0.36.0  # This will be auto-updated
```

## 📋 Update Strategies

### 1. **semver** (Semantic Versioning)
- Updates to latest semantic version
- Example: `1.2.3` → `1.2.4` or `1.3.0`

```yaml
argocd-image-updater.argoproj.io/update-strategy: semver
```

### 2. **latest**
- Always use the `latest` tag

```yaml
argocd-image-updater.argoproj.io/update-strategy: latest
```

### 3. **digest**
- Pin to specific image digest

```yaml
argocd-image-updater.argoproj.io/update-strategy: digest
```

### 4. **name**
- Sort tags alphabetically

```yaml
argocd-image-updater.argoproj.io/update-strategy: name
```

## 🎯 Version Constraints

### Allow only patch updates (1.2.x)
```yaml
argocd-image-updater.argoproj.io/homepage.allow-tags: regexp:^1\\.2\\.
```

### Allow minor and patch updates (1.x.x)
```yaml
argocd-image-updater.argoproj.io/homepage.allow-tags: regexp:^1\\.
```

### Ignore pre-release versions
```yaml
argocd-image-updater.argoproj.io/homepage.ignore-tags: regexp:^.*-(alpha|beta|rc).*$
```

## 🔐 Git Write-Back Setup

For Image Updater to commit changes, create a Git credentials secret:

```bash
# Create SSH key for Git write-back
ssh-keygen -t ed25519 -C "argocd-image-updater@homelab" -f ~/.ssh/argocd-image-updater -N ""

# Add public key to GitHub as deploy key with write access
cat ~/.ssh/argocd-image-updater.pub

# Create Kubernetes secret
kubectl create secret generic git-creds \
  --from-file=sshPrivateKey=$HOME/.ssh/argocd-image-updater \
  -n argocd

# Label the secret
kubectl label secret git-creds \
  argocd.argoproj.io/secret-type=repository \
  -n argocd
```

## 📊 Monitoring

Check Image Updater logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater -f
```

View metrics in Prometheus/Grafana:
- `argocd_image_updater_applications_watched`
- `argocd_image_updater_images_updated_total`

## 🚀 Example: Auto-Update All Media Apps

```yaml
# argocd-apps/jellyfin.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: jellyfin
  namespace: argocd
  annotations:
    argocd-image-updater.argoproj.io/image-list: jellyfin=ghcr.io/jellyfin/jellyfin
    argocd-image-updater.argoproj.io/jellyfin.update-strategy: semver
    argocd-image-updater.argoproj.io/jellyfin.allow-tags: regexp:^10\\.
    argocd-image-updater.argoproj.io/write-back-method: git
spec:
  # ... rest of spec
```

## ⚙️ Configuration

Edit `apps/argocd-image-updater/custom-values.yaml` to:
- Change update interval (default: 2 minutes)
- Add custom registries
- Configure Git settings
- Adjust resource limits

## 🔍 Troubleshooting

### Image Updater not updating

1. Check annotations are correct:
```bash
kubectl get application homepage -n argocd -o yaml | grep annotations -A 10
```

2. Check Image Updater logs:
```bash
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-image-updater --tail=100
```

3. Verify Git credentials:
```bash
kubectl get secret git-creds -n argocd
```

### Force immediate update

```bash
# Restart Image Updater
kubectl rollout restart deployment argocd-image-updater -n argocd
```

## 📚 Resources

- [ArgoCD Image Updater Docs](https://argocd-image-updater.readthedocs.io/)
- [Update Strategies](https://argocd-image-updater.readthedocs.io/en/stable/basics/update-strategies/)
- [Configuration Options](https://argocd-image-updater.readthedocs.io/en/stable/configuration/applications/)

