# EMQX Secret Management with Sealed Secrets

This guide explains how to manage EMQX passwords securely using Sealed Secrets in a GitOps workflow.

## 🔐 Overview

**Problem:** We can't commit plaintext passwords to Git.

**Solution:** Use Sealed Secrets to encrypt secrets that can be safely committed to Git.

**How it works:**
1. Sealed Secrets controller runs in your cluster with a private key
2. You encrypt secrets using the controller's public key
3. Encrypted `SealedSecret` is safe to commit to Git
4. Controller automatically decrypts it in-cluster to create a regular `Secret`

---

## 📋 Prerequisites

1. **Install Sealed Secrets Controller**

```bash
# Add to ArgoCD
kubectl apply -f argocd-apps/sealed-secrets.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n kube-system --timeout=300s
```

2. **Install kubeseal CLI**

```bash
# Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/kubeseal-0.27.1-linux-amd64.tar.gz
tar -xvzf kubeseal-0.27.1-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal

# macOS
brew install kubeseal

# Verify installation
kubeseal --version
```

---

## 🔧 Creating Encrypted Secrets for EMQX

### Step 1: Create a temporary secret file (NOT committed to Git)

Create a file called `emqx-secret-temp.yaml` (add to .gitignore):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: emqx-credentials
  namespace: emqx
type: Opaque
stringData:
  dashboard_username: admin
  dashboard_password: "YOUR_STRONG_PASSWORD_HERE"  # Change this!
  mqtt_username: mqtt_user
  mqtt_password: "YOUR_MQTT_PASSWORD_HERE"  # Change this!
```

### Step 2: Generate strong passwords

```bash
# Generate random passwords
echo "Dashboard password: $(openssl rand -base64 32)"
echo "MQTT password: $(openssl rand -base64 32)"

# Edit the temp file with your passwords
nano emqx-secret-temp.yaml
```

### Step 3: Encrypt the secret with kubeseal

```bash
# Encrypt the secret
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < emqx-secret-temp.yaml \
  > apps/emqx/sealed-secret.yaml

# Verify the encrypted secret was created
cat apps/emqx/sealed-secret.yaml
```

The output will look like this (safe to commit):

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: emqx-credentials
  namespace: emqx
spec:
  encryptedData:
    dashboard_password: AgBj8F7x... (long encrypted string)
    dashboard_username: AgCK9mP... (long encrypted string)
    mqtt_password: AgDL2nQ... (long encrypted string)
    mqtt_username: AgEM3oR... (long encrypted string)
  template:
    metadata:
      name: emqx-credentials
      namespace: emqx
    type: Opaque
```

### Step 4: Delete the temporary file

```bash
# IMPORTANT: Delete the plaintext secret file
rm emqx-secret-temp.yaml

# Verify it's gone
ls -la emqx-secret-temp.yaml  # Should show "No such file"
```

### Step 5: Commit the encrypted secret to Git

```bash
# Add the encrypted secret
git add apps/emqx/sealed-secret.yaml

# Commit
git commit -m "Add encrypted EMQX credentials"

# Push to Git
git push
```

### Step 6: Apply to cluster

```bash
# The SealedSecret will automatically be decrypted by the controller
kubectl apply -f apps/emqx/sealed-secret.yaml

# Verify the regular Secret was created
kubectl get secret emqx-credentials -n emqx

# Check the secret (base64 encoded, but decrypted)
kubectl get secret emqx-credentials -n emqx -o yaml
```

---

## 🔄 Updating Secrets

When you need to change passwords:

### Method 1: Create new encrypted secret

```bash
# 1. Create temp file with new passwords
cat > emqx-secret-temp.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: emqx-credentials
  namespace: emqx
type: Opaque
stringData:
  dashboard_username: admin
  dashboard_password: "NEW_PASSWORD_HERE"
  mqtt_username: mqtt_user
  mqtt_password: "NEW_MQTT_PASSWORD_HERE"
EOF

# 2. Encrypt
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < emqx-secret-temp.yaml \
  > apps/emqx/sealed-secret.yaml

# 3. Delete temp file
rm emqx-secret-temp.yaml

# 4. Commit and push
git add apps/emqx/sealed-secret.yaml
git commit -m "Update EMQX credentials"
git push

# 5. Apply
kubectl apply -f apps/emqx/sealed-secret.yaml

# 6. Restart EMQX pods to pick up new credentials
kubectl rollout restart statefulset emqx -n emqx
```

### Method 2: Patch existing secret

```bash
# Encrypt a single value
echo -n "new-password" | kubeseal \
  --raw \
  --name=emqx-credentials \
  --namespace=emqx \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  --from-file=/dev/stdin

# This outputs an encrypted string you can use to patch the SealedSecret
```

---

## 🔑 Backing Up the Encryption Key

**CRITICAL:** If you lose the sealed-secrets private key, you cannot decrypt your secrets!

### Backup the key

```bash
# Export the private key
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > sealed-secrets-key-backup.yaml

# Store this file SECURELY (NOT in Git!)
# Options:
# - Password manager (1Password, Bitwarden)
# - Encrypted USB drive
# - Secure cloud storage (encrypted)
```

### Restore the key (disaster recovery)

```bash
# If you need to restore the cluster
kubectl apply -f sealed-secrets-key-backup.yaml

# Restart the controller
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

---

## 🛠️ Troubleshooting

### SealedSecret not decrypting

```bash
# Check controller logs
kubectl logs -n kube-system -l app.kubernetes.io/name=sealed-secrets

# Check SealedSecret status
kubectl get sealedsecret emqx-credentials -n emqx -o yaml

# Verify controller is running
kubectl get pods -n kube-system -l app.kubernetes.io/name=sealed-secrets
```

### "no key could decrypt secret" error

This means:
- The secret was encrypted with a different key
- The controller's private key is missing
- You need to re-encrypt the secret with the current public key

```bash
# Get the current public key
kubeseal --fetch-cert \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > pub-cert.pem

# Re-encrypt your secret using this certificate
kubeseal --format=yaml \
  --cert=pub-cert.pem \
  < emqx-secret-temp.yaml \
  > apps/emqx/sealed-secret.yaml
```

### Viewing decrypted secrets (for debugging)

```bash
# View the decrypted secret (base64 encoded)
kubectl get secret emqx-credentials -n emqx -o yaml

# Decode a specific value
kubectl get secret emqx-credentials -n emqx \
  -o jsonpath='{.data.dashboard_password}' | base64 -d
```

---

## 📚 Best Practices

1. ✅ **Never commit plaintext secrets** to Git
2. ✅ **Always delete temporary secret files** after encryption
3. ✅ **Backup the sealed-secrets private key** securely
4. ✅ **Use strong passwords** (32+ characters)
5. ✅ **Rotate passwords regularly** (every 90 days)
6. ✅ **Add `*-temp.yaml` to .gitignore** to prevent accidents
7. ✅ **Test decryption** after creating SealedSecrets
8. ✅ **Document who has access** to the backup key

---

## 🔗 Alternative: Using kubectl create secret

You can also create secrets directly without a temp file:

```bash
# Create and encrypt in one command
kubectl create secret generic emqx-credentials \
  --namespace=emqx \
  --from-literal=dashboard_username=admin \
  --from-literal=dashboard_password="YOUR_PASSWORD" \
  --from-literal=mqtt_username=mqtt_user \
  --from-literal=mqtt_password="YOUR_MQTT_PASSWORD" \
  --dry-run=client -o yaml | \
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  > apps/emqx/sealed-secret.yaml
```

---

## 📖 Additional Resources

- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)
- [GitOps Secret Management Best Practices](https://www.weave.works/blog/managing-secrets-in-flux)
- [kubeseal CLI Reference](https://github.com/bitnami-labs/sealed-secrets#usage)

---

## 🎯 Quick Reference

```bash
# Install controller
kubectl apply -f argocd-apps/sealed-secrets.yaml

# Install CLI
brew install kubeseal  # macOS
# or download from GitHub releases

# Encrypt secret
kubeseal --format=yaml < secret.yaml > sealed-secret.yaml

# Apply encrypted secret
kubectl apply -f sealed-secret.yaml

# Backup encryption key
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/sealed-secrets-key=active \
  -o yaml > backup.yaml

# Fetch public cert
kubeseal --fetch-cert > pub-cert.pem
```

