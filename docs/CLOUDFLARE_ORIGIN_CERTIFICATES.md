# Cloudflare Origin Certificates for roomiorentals.com

This guide explains how to set up Cloudflare Origin Certificates so that Uptime Kuma (and other local services) can trust the SSL certificates served by Traefik.

## Why Cloudflare Origin Certificates?

Since you're using **Cloudflare Tunnel**, Let's Encrypt HTTP-01 challenges don't work because:
- External traffic goes through Cloudflare's edge, not directly to your Traefik
- Let's Encrypt can't reach the ACME challenge endpoint on your server

**Cloudflare Origin Certificates** solve this by:
- Providing free SSL certificates trusted between Cloudflare and your origin server
- Working perfectly with Cloudflare Tunnel
- Valid for up to 15 years
- Supporting wildcards (*.roomiorentals.com)

## Step 1: Create Cloudflare Origin Certificate

1. Go to [Cloudflare Dashboard](https://dash.cloudflare.com/)
2. Select your domain: `roomiorentals.com`
3. Navigate to **SSL/TLS** → **Origin Server**
4. Click **"Create Certificate"**
5. Configure the certificate:
   - **Private key type**: RSA (2048)
   - **Hostnames**: 
     - `roomiorentals.com`
     - `*.roomiorentals.com` (wildcard for all subdomains)
   - **Certificate Validity**: 15 years (maximum)
6. Click **"Create"**
7. **IMPORTANT**: Copy both:
   - **Origin Certificate** (the long PEM-encoded certificate)
   - **Private Key** (the private key)
   
   ⚠️ **Save these immediately! You won't be able to see the private key again!**

## Step 2: Create Kubernetes Secret

Save the certificate and key to files temporarily:

```bash
# Create a temporary directory
mkdir -p /tmp/cloudflare-certs
cd /tmp/cloudflare-certs

# Save the certificate (paste the Origin Certificate from Cloudflare)
cat > tls.crt << 'EOF'
-----BEGIN CERTIFICATE-----
[PASTE YOUR ORIGIN CERTIFICATE HERE]
-----END CERTIFICATE-----
EOF

# Save the private key (paste the Private Key from Cloudflare)
cat > tls.key << 'EOF'
-----BEGIN PRIVATE KEY-----
[PASTE YOUR PRIVATE KEY HERE]
-----END PRIVATE KEY-----
EOF
```

Create the Kubernetes secret:

```bash
# For production
kubectl create secret tls roomio-cloudflare-cert \
  --cert=tls.crt \
  --key=tls.key \
  -n roomio-prod

# For dev
kubectl create secret tls dev-roomio-cloudflare-cert \
  --cert=tls.crt \
  --key=tls.key \
  -n roomio-dev

# For staging
kubectl create secret tls staging-roomio-cloudflare-cert \
  --cert=tls.crt \
  --key=tls.key \
  -n roomio-staging

# Clean up the temporary files
rm -rf /tmp/cloudflare-certs
```

## Step 3: Update Ingress to Use the Certificate

Update your ingress resources to use the Cloudflare Origin Certificate:

### Production Ingress

```bash
kubectl patch ingress prod-roomio-ingress -n roomio-prod --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["roomiorentals.com"],
        "secretName": "roomio-cloudflare-cert"
      }
    ]
  }
]'
```

### Dev Ingress

```bash
kubectl patch ingress dev-roomio-ingress -n roomio-dev --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["dev.roomiorentals.com"],
        "secretName": "dev-roomio-cloudflare-cert"
      }
    ]
  }
]'
```

### Staging Ingress

```bash
kubectl patch ingress staging-roomio-ingress -n roomio-staging --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/tls",
    "value": [
      {
        "hosts": ["staging.roomiorentals.com"],
        "secretName": "staging-roomio-cloudflare-cert"
      }
    ]
  }
]'
```

## Step 4: Configure Cloudflare SSL/TLS Mode

1. Go to Cloudflare Dashboard → **SSL/TLS** → **Overview**
2. Set SSL/TLS encryption mode to **"Full (strict)"**
   - This ensures end-to-end encryption
   - Cloudflare will verify your origin certificate

## Step 5: Verify the Setup

Test from inside the Uptime Kuma pod:

```bash
# Test HTTPS with certificate verification
kubectl exec -n uptime-kuma deployment/uptime-kuma -- \
  curl -I --max-time 5 https://roomiorentals.com

# Should return HTTP/2 200 without SSL errors!
```

Test from your local machine:

```bash
curl -I https://roomiorentals.com
# Should work perfectly!
```

## Step 6: Update Uptime Kuma Monitor

1. Open Uptime Kuma dashboard
2. Edit the "Roomio Rentals" monitor
3. Make sure **"Ignore TLS/SSL error"** is **UNCHECKED** ✅
4. The monitor should now work with proper SSL verification!

## Troubleshooting

### Certificate Not Working

Check if the secret was created correctly:

```bash
kubectl get secret roomio-cloudflare-cert -n roomio-prod
kubectl describe secret roomio-cloudflare-cert -n roomio-prod
```

### Traefik Not Using the Certificate

Check Traefik logs:

```bash
kubectl logs -n kube-system -l app.kubernetes.io/name=traefik --tail=50
```

### Still Getting Self-Signed Certificate Errors

1. Verify the ingress has the TLS section:
   ```bash
   kubectl get ingress prod-roomio-ingress -n roomio-prod -o yaml | grep -A 10 "tls:"
   ```

2. Restart Traefik to pick up the new certificate:
   ```bash
   kubectl rollout restart deployment/traefik -n kube-system
   ```

## Security Notes

- ✅ Origin Certificates are only trusted between Cloudflare and your origin
- ✅ They are NOT publicly trusted (but that's fine for your use case)
- ✅ Cloudflare's edge still presents publicly trusted certificates to visitors
- ✅ End-to-end encryption is maintained

## Certificate Renewal

Cloudflare Origin Certificates are valid for up to 15 years, so you won't need to renew them frequently. When renewal is needed:

1. Create a new Origin Certificate in Cloudflare Dashboard
2. Update the Kubernetes secrets with the new certificate
3. Traefik will automatically pick up the new certificate

## Alternative: Use SealedSecrets (Recommended for GitOps)

If you want to store the certificate in Git (encrypted), use SealedSecrets:

```bash
# Create a sealed secret
kubectl create secret tls roomio-cloudflare-cert \
  --cert=tls.crt \
  --key=tls.key \
  --dry-run=client -o yaml | \
  kubeseal -o yaml > roomio-cloudflare-cert-sealed.yaml

# Commit to Git
git add roomio-cloudflare-cert-sealed.yaml
git commit -m "Add Cloudflare Origin Certificate for roomiorentals.com"
git push
```

---

**That's it!** Your Uptime Kuma should now be able to monitor `https://roomiorentals.com` with proper SSL certificate verification! 🎉

