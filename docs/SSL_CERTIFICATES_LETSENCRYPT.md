# SSL Certificates with Let's Encrypt

This document explains how SSL certificates are configured for `roomiorentals.com` using Let's Encrypt and cert-manager.

## Overview

All domains (`roomiorentals.com`, `dev.roomiorentals.com`, `staging.roomiorentals.com`) use **publicly trusted Let's Encrypt certificates** that are automatically issued and renewed by cert-manager.

## Why Let's Encrypt?

- ✅ **Publicly Trusted**: Certificates are trusted by all browsers and systems worldwide
- ✅ **Free**: No cost for certificates
- ✅ **Automatic Renewal**: cert-manager handles renewal automatically (90-day validity)
- ✅ **Works with Cloudflare Tunnel**: Uses DNS-01 challenge instead of HTTP-01

## Architecture

```
Internet → Cloudflare Edge (Public SSL) → Cloudflare Tunnel → Traefik (Let's Encrypt SSL) → Application
```

- **External users**: See Cloudflare's publicly trusted certificate
- **Internal traffic**: Uses Let's Encrypt certificate on Traefik
- **End-to-end encryption**: Traffic is encrypted from browser to application

## Configuration

### 1. ClusterIssuer

Located at: `cluster/cert-manager/letsencrypt-clusterissuer.yaml`

Two ClusterIssuers are configured:
- `letsencrypt-prod`: Production certificates (rate-limited)
- `letsencrypt-staging`: Staging certificates (for testing)

Both use **DNS-01 challenge** with Cloudflare DNS:

```yaml
solvers:
  - dns01:
      cloudflare:
        apiTokenSecretRef:
          name: cloudflare-api-token-secret
          key: api-token
    selector:
      dnsZones:
        - roomiorentals.com
```

### 2. Ingress Annotations

Each ingress must have the cert-manager annotation:

```yaml
metadata:
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  tls:
    - hosts:
        - roomiorentals.com
      secretName: roomio-tls-letsencrypt
```

### 3. Certificate Lifecycle

1. **Creation**: When an ingress with cert-manager annotation is created, cert-manager automatically creates a Certificate resource
2. **Issuance**: cert-manager creates a DNS TXT record in Cloudflare to prove domain ownership
3. **Validation**: Let's Encrypt validates the DNS record
4. **Storage**: Certificate is stored in a Kubernetes Secret
5. **Renewal**: cert-manager automatically renews certificates 30 days before expiration

## Current Certificates

| Domain | Namespace | Secret Name | Status |
|--------|-----------|-------------|--------|
| roomiorentals.com | roomio-prod | roomio-tls-letsencrypt | ✅ Ready |
| dev.roomiorentals.com | roomio-dev | dev-roomio-tls-letsencrypt | ✅ Ready |
| staging.roomiorentals.com | roomio-staging | staging-roomio-tls-letsencrypt | ✅ Ready |

## Verification

### Check Certificate Status

```bash
# View all certificates
kubectl get certificate -A

# Check specific certificate
kubectl describe certificate roomio-tls-letsencrypt -n roomio-prod

# View certificate details
kubectl get secret roomio-tls-letsencrypt -n roomio-prod -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### Test HTTPS Connection

```bash
# From inside cluster
kubectl exec -n uptime-kuma deployment/uptime-kuma -- curl -I https://roomiorentals.com

# From local machine
curl -I https://roomiorentals.com

# Check certificate issuer
openssl s_client -connect roomiorentals.com:443 -servername roomiorentals.com </dev/null 2>/dev/null | openssl x509 -noout -issuer
```

Expected output:
```
issuer=C = US, O = Let's Encrypt, CN = R12
```

## Troubleshooting

### Certificate Not Ready

Check the certificate status:
```bash
kubectl describe certificate roomio-tls-letsencrypt -n roomio-prod
```

Common issues:
- **DNS propagation delay**: Wait a few minutes for DNS TXT records to propagate
- **Cloudflare API token invalid**: Check the secret `cloudflare-api-token-secret`
- **Rate limiting**: Let's Encrypt has rate limits (50 certificates per domain per week)

### Check Certificate Request

```bash
kubectl get certificaterequest -n roomio-prod
kubectl describe certificaterequest <name> -n roomio-prod
```

### Check ACME Order and Challenge

```bash
kubectl get order -n roomio-prod
kubectl describe order <name> -n roomio-prod

kubectl get challenge -n roomio-prod
kubectl describe challenge <name> -n roomio-prod
```

### Check cert-manager Logs

```bash
kubectl logs -n cert-manager -l app=cert-manager --tail=100
```

## Cloudflare Configuration

### SSL/TLS Mode

In Cloudflare Dashboard → SSL/TLS → Overview:
- **Mode**: Full (strict)
- This ensures end-to-end encryption and validates the origin certificate

### DNS Records

Ensure these DNS records exist:
- `roomiorentals.com` → CNAME to Cloudflare Tunnel
- `dev.roomiorentals.com` → CNAME to Cloudflare Tunnel
- `staging.roomiorentals.com` → CNAME to Cloudflare Tunnel

## Adding New Domains

To add a new domain to Let's Encrypt:

1. **Update ClusterIssuer** (if using a different domain):
   ```bash
   # Edit cluster/cert-manager/letsencrypt-clusterissuer.yaml
   # Add the new domain to dnsZones selector
   ```

2. **Create Ingress with annotation**:
   ```yaml
   apiVersion: networking.k8s.io/v1
   kind: Ingress
   metadata:
     name: my-app-ingress
     annotations:
       cert-manager.io/cluster-issuer: "letsencrypt-prod"
   spec:
     tls:
       - hosts:
           - myapp.roomiorentals.com
         secretName: myapp-tls-letsencrypt
     rules:
       - host: myapp.roomiorentals.com
         http:
           paths:
             - path: /
               pathType: Prefix
               backend:
                 service:
                   name: myapp-service
                   port:
                     number: 80
   ```

3. **Apply and wait**:
   ```bash
   kubectl apply -f ingress.yaml
   kubectl get certificate -w
   ```

## Security Notes

- ✅ Certificates are valid for 90 days and auto-renewed
- ✅ Private keys are stored securely in Kubernetes Secrets
- ✅ Cloudflare API token has minimal permissions (DNS edit only)
- ✅ End-to-end encryption from browser to application
- ✅ Publicly trusted by all browsers and systems

## Monitoring

Uptime Kuma monitors all three domains:
- `https://roomiorentals.com`
- `https://dev.roomiorentals.com`
- `https://staging.roomiorentals.com`

All monitors should show **green status** with valid SSL certificates.

## References

- [cert-manager Documentation](https://cert-manager.io/docs/)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [Cloudflare DNS-01 Challenge](https://cert-manager.io/docs/configuration/acme/dns01/cloudflare/)

