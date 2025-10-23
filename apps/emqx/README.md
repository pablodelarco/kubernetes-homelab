# EMQX MQTT Broker - Secure Setup

This directory contains the configuration for EMQX MQTT broker with SSL/TLS encryption and secure credential management.

## 🔐 Security Features

- **Encrypted MQTT**: MQTTS on port 8883 (SSL/TLS)
- **Encrypted WebSocket**: WSS on port 8084 (SSL/TLS)
- **Secure Credentials**: Passwords stored in Kubernetes Secrets
- **TLS Certificates**: Managed by cert-manager with auto-renewal

## 📁 Files

- `custom-values.yaml` - Helm chart values for EMQX
- `sealed-secret.yaml` - Encrypted secret (safe to commit to Git)
- `certificate.yaml` - cert-manager certificates for SSL/TLS
- `ingress.yaml` - Tailscale ingress for dashboard access
- `SECRET_MANAGEMENT.md` - **Complete guide for managing secrets with Sealed Secrets**

## 🚀 Deployment Steps

### 1. Install Sealed Secrets Controller

```bash
# Deploy Sealed Secrets via ArgoCD
kubectl apply -f argocd-apps/sealed-secrets.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=sealed-secrets -n kube-system --timeout=300s

# Install kubeseal CLI (macOS)
brew install kubeseal

# Or Linux
wget https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/kubeseal-0.27.1-linux-amd64.tar.gz
tar -xvzf kubeseal-0.27.1-linux-amd64.tar.gz
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```

### 2. Create Encrypted Secret

**See `SECRET_MANAGEMENT.md` for detailed instructions.**

Quick version:

```bash
# Create temporary secret file (NOT committed to Git)
cat > emqx-secret-temp.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: emqx-credentials
  namespace: emqx
type: Opaque
stringData:
  dashboard_username: admin
  dashboard_password: "$(openssl rand -base64 32)"
  mqtt_username: mqtt_user
  mqtt_password: "$(openssl rand -base64 32)"
EOF

# Encrypt it
kubeseal --format=yaml \
  --controller-name=sealed-secrets-controller \
  --controller-namespace=kube-system \
  < emqx-secret-temp.yaml \
  > apps/emqx/sealed-secret.yaml

# Delete temp file
rm emqx-secret-temp.yaml

# Commit encrypted secret to Git
git add apps/emqx/sealed-secret.yaml
git commit -m "Add encrypted EMQX credentials"
git push
```

### 3. Deploy EMQX

```bash
# Add EMQX Helm repo
helm repo add emqx https://repos.emqx.io/charts
helm repo update

# Create namespace
kubectl create namespace emqx

# Apply encrypted secret and certificates
kubectl apply -f apps/emqx/sealed-secret.yaml
kubectl apply -f apps/emqx/certificate.yaml

# Wait for certificates
kubectl wait --for=condition=ready certificate -n emqx --all --timeout=120s

# Deploy via ArgoCD
kubectl apply -f argocd-apps/emqx.yaml

# Optional: Apply Tailscale ingress
kubectl apply -f apps/emqx/ingress.yaml
```

### 4. Wait for Certificates

```bash
# Check certificate status
kubectl get certificate -n emqx

# Should show READY=True
# NAME                READY   SECRET             AGE
# emqx-ca             True    emqx-ca-secret     1m
# emqx-server-cert    True    emqx-tls-secret    1m
```

### 5. Verify Deployment

```bash
# Check pods
kubectl get pods -n emqx

# Check service and get LoadBalancer IP
kubectl get svc -n emqx

# Check logs
kubectl logs -n emqx -l app.kubernetes.io/name=emqx
```

## 🌐 Access

### MQTT Broker

**Secure (MQTTS) - Recommended:**
```
mqtts://<LOADBALANCER_IP>:8883
```

**Plain (MQTT) - Internal only:**
```
mqtt://<LOADBALANCER_IP>:1883
```

**WebSocket Secure (WSS):**
```
wss://<LOADBALANCER_IP>:8084
```

### Dashboard

**Via LoadBalancer:**
```
http://<LOADBALANCER_IP>:18083
```

**Via Tailscale (if ingress applied):**
```
https://emqx
```

**Login:**
- Username: `admin`
- Password: (from secret.yaml)

## 🔧 Configuration

### Enable MQTT Authentication

By default, anonymous access is allowed. To require authentication:

1. Log into the dashboard
2. Go to **Access Control** → **Authentication**
3. Create a new authenticator (Built-in Database)
4. Add users with username/password
5. Disable anonymous access in **Settings**

Or via configuration:
```yaml
emqxConfig:
  EMQX_ALLOW_ANONYMOUS: "false"
```

### Client Certificate (CA)

For clients to trust the MQTTS connection, they need the CA certificate:

```bash
# Extract CA certificate
kubectl get secret emqx-ca-secret -n emqx -o jsonpath='{.data.ca\.crt}' | base64 -d > emqx-ca.crt

# Use this file in your MQTT clients
```

## 🏠 Home Assistant Integration

Add to your Home Assistant `configuration.yaml`:

```yaml
mqtt:
  broker: <LOADBALANCER_IP>
  port: 8883  # MQTTS port
  username: mqtt_user
  password: !secret mqtt_password
  certificate: /config/emqx-ca.crt  # Copy CA cert to HA config directory
  tls_insecure: false  # Set to true if using self-signed certs
```

## 🔄 Certificate Renewal

Certificates are automatically renewed by cert-manager 30 days before expiration.

To manually renew:
```bash
# Delete the certificate (will be recreated)
kubectl delete certificate emqx-server-cert -n emqx

# Check renewal
kubectl get certificate -n emqx -w
```

## 🧪 Testing MQTTS Connection

### Using mosquitto_pub/sub

```bash
# Get the CA certificate first
kubectl get secret emqx-ca-secret -n emqx -o jsonpath='{.data.ca\.crt}' | base64 -d > ca.crt

# Get LoadBalancer IP
BROKER_IP=$(kubectl get svc emqx -n emqx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Test publish (with TLS)
mosquitto_pub -h $BROKER_IP -p 8883 \
  --cafile ca.crt \
  -t test/topic \
  -m "Hello Secure MQTT"

# Test subscribe (with TLS)
mosquitto_sub -h $BROKER_IP -p 8883 \
  --cafile ca.crt \
  -t test/topic
```

### Using MQTT Explorer (GUI)

1. Download [MQTT Explorer](http://mqtt-explorer.com/)
2. Create new connection:
   - Protocol: `mqtts://`
   - Host: `<LOADBALANCER_IP>`
   - Port: `8883`
   - Encryption: Enable
   - CA Certificate: Upload `emqx-ca.crt`

## 📊 Monitoring

EMQX exports Prometheus metrics on port 18083.

If you have kube-prometheus-stack installed, create a ServiceMonitor:

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: emqx
  namespace: emqx
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: emqx
  endpoints:
    - port: dashboard
      path: /api/v5/prometheus/stats
```

## 🔒 Security Best Practices

1. ✅ **Change default passwords** in `secret.yaml`
2. ✅ **Use MQTTS (8883)** instead of plain MQTT (1883)
3. ✅ **Enable authentication** in the dashboard
4. ✅ **Use ACLs** to restrict topic access per user
5. ✅ **Rotate passwords** regularly
6. ✅ **Monitor connections** via dashboard
7. ✅ **Use strong passwords** (min 16 characters)
8. ✅ **Backup secrets** securely

## 🐛 Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n emqx -l app.kubernetes.io/name=emqx
kubectl logs -n emqx -l app.kubernetes.io/name=emqx
```

### Certificate issues
```bash
kubectl describe certificate -n emqx
kubectl get certificaterequest -n emqx
```

### Connection refused
```bash
# Check if service has LoadBalancer IP
kubectl get svc -n emqx

# Check if ports are open
kubectl get svc emqx -n emqx -o yaml
```

### TLS handshake errors
- Ensure client has the CA certificate
- Check certificate validity: `kubectl get certificate -n emqx`
- Verify certificate DNS names match connection hostname

## 📚 Resources

- [EMQX Documentation](https://www.emqx.io/docs/en/latest/)
- [EMQX Dashboard Guide](https://www.emqx.io/docs/en/latest/dashboard/introduction.html)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [MQTT Protocol](https://mqtt.org/)

