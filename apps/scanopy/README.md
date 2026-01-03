# Scanopy on Kubernetes - Installation Guide

This guide walks you through deploying Scanopy (network scanner) on Kubernetes, covering common pitfalls and their solutions.

## Overview

Scanopy consists of two components:
- **Server**: Web UI and API (stores data in PostgreSQL)
- **Daemon**: Network scanner agent that discovers devices

## Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   PostgreSQL    │◄────│  Scanopy Server │◄────│  Scanopy Daemon │
│   (StatefulSet) │     │   (Deployment)  │     │   (Deployment)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                              │                        │
                              │ ClusterIP              │ hostNetwork
                              ▼                        ▼
                        ┌───────────┐           ┌───────────────┐
                        │  Ingress  │           │ Physical LAN  │
                        └───────────┘           └───────────────┘
```

## Prerequisites

- Kubernetes cluster with:
  - Storage class (e.g., Longhorn)
  - Ingress controller or Gateway API
  - Sealed Secrets controller (for secret management)
- `kubectl` and `kubeseal` CLI tools

## Step 1: Create Namespace

```yaml
# namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: scanopy
```

## Step 2: Deploy PostgreSQL

Create PVC and StatefulSet for PostgreSQL:

```yaml
# postgresql-pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scanopy-postgresql-data
  namespace: scanopy
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: longhorn
  resources:
    requests:
      storage: 5Gi
```

```yaml
# postgresql-sts.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: scanopy-postgresql
  namespace: scanopy
spec:
  serviceName: postgres
  replicas: 1
  selector:
    matchLabels:
      app: scanopy-postgresql
  template:
    metadata:
      labels:
        app: scanopy-postgresql
    spec:
      containers:
        - name: postgresql
          image: postgres:16-alpine
          env:
            - name: POSTGRES_USER
              value: "scanopy"
            - name: POSTGRES_DB
              value: "scanopy"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: scanopy-secrets
                  key: POSTGRES_PASSWORD
          ports:
            - containerPort: 5432
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: scanopy-postgresql-data
```

## Step 3: Deploy Scanopy Server

```yaml
# server-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanopy-server
  namespace: scanopy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scanopy-server
  template:
    metadata:
      labels:
        app: scanopy-server
    spec:
      containers:
        - name: server
          image: ghcr.io/scanopy/scanopy/server:latest
          ports:
            - containerPort: 60072
          env:
            - name: DATABASE_URL
              value: "postgres://scanopy:$(POSTGRES_PASSWORD)@postgres.scanopy.svc.cluster.local:5432/scanopy"
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: scanopy-secrets
                  key: POSTGRES_PASSWORD
            - name: TZ
              value: "Europe/Madrid"
```

> ⚠️ **Common Mistake**: Using wrong database URL format. The correct format is:
> `postgres://user:password@host:port/database`

## Step 4: Create Services

```yaml
# postgresql-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: scanopy
spec:
  selector:
    app: scanopy-postgresql
  ports:
    - port: 5432
```

```yaml
# server-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: server
  namespace: scanopy
spec:
  selector:
    app: scanopy-server
  ports:
    - port: 60072
```

## Step 5: Create Secrets

Create a temporary secret file (DO NOT COMMIT):

```yaml
# /tmp/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: scanopy-secrets
  namespace: scanopy
type: Opaque
stringData:
  POSTGRES_PASSWORD: "your-strong-password"
  SCANOPY_DAEMON_API_KEY: "will-be-updated-later"
```

Seal and apply:
```bash
kubeseal --format=yaml < /tmp/secret.yaml > apps/scanopy/secret-sealed.yaml
rm /tmp/secret.yaml
kubectl apply -f apps/scanopy/secret-sealed.yaml
```

## Step 6: Configure Ingress/Gateway

Example using Gateway API:

```yaml
# httproute.yaml
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: scanopy
  namespace: scanopy
spec:
  parentRefs:
    - name: internal-gateway
      namespace: gateway
  hostnames:
    - scanopy.homelab
  rules:
    - matches:
        - path:
            type: PathPrefix
            value: /
      backendRefs:
        - name: server
          port: 60072
```

## Step 7: Access the Server UI and Generate Daemon Key

1. Apply all manifests and wait for server to be ready
2. Access the Scanopy UI at your configured hostname (e.g., `http://scanopy.homelab`)
3. Create an account and log in
4. Navigate to **Settings → Networks → Add Network**
5. Create a network (e.g., "homelab")
6. Click **"Generate Key"** to get daemon configuration

You'll see output like this:

```bash
sudo scanopy-daemon --server-url http://scanopy.homelab \
  --network-id 252286e7-b169-49d8-916a-1380f5241cef \
  --daemon-api-key c77bce838fd24a12b22f6bff01b6619c \
  --user-id 98e47302-d3be-48c7-9efb-00b3697aaf0c \
  --name homelab-daemon --mode pull
```

**Save these values!** You'll need them for the daemon deployment.

## Step 8: Deploy the Daemon

> ⚠️ **Critical Configuration**: The daemon needs specific environment variables that match what the server generated. This is the most common source of errors.

```yaml
# daemon-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scanopy-daemon
  namespace: scanopy
spec:
  replicas: 1
  strategy:
    type: Recreate  # Required for hostNetwork
  selector:
    matchLabels:
      app: scanopy-daemon
  template:
    metadata:
      labels:
        app: scanopy-daemon
    spec:
      enableServiceLinks: false  # Prevents conflicts with service env vars
      hostNetwork: true          # Required for network scanning
      dnsPolicy: ClusterFirstWithHostNet
      nodeSelector:
        kubernetes.io/hostname: beelink  # Pin to specific node
      containers:
        - name: daemon
          image: ghcr.io/scanopy/scanopy/daemon:latest
          env:
            # Server connection (use internal K8s DNS)
            - name: SCANOPY_SERVER_URL
              value: "http://server.scanopy.svc.cluster.local:60072"

            # From "Generate Key" in UI - Network ID
            - name: SCANOPY_NETWORK_ID
              value: "YOUR-NETWORK-ID-HERE"

            # From "Generate Key" in UI - API Key (use sealed secret)
            - name: SCANOPY_DAEMON_API_KEY
              valueFrom:
                secretKeyRef:
                  name: scanopy-secrets
                  key: SCANOPY_DAEMON_API_KEY

            # From "Generate Key" in UI - User ID
            - name: SCANOPY_USER_ID
              value: "YOUR-USER-ID-HERE"

            # Daemon name (appears in UI)
            - name: SCANOPY_NAME
              value: "homelab-daemon"

            # Mode: "Pull" recommended for Kubernetes
            - name: SCANOPY_MODE
              value: "Pull"

            - name: TZ
              value: "Europe/Madrid"
          securityContext:
            capabilities:
              add:
                - NET_ADMIN
                - NET_RAW
```

### Environment Variables Explained

| Variable | Source | Description |
|----------|--------|-------------|
| `SCANOPY_SERVER_URL` | Manual | Internal K8s service URL |
| `SCANOPY_NETWORK_ID` | UI → Generate Key | UUID of the network to scan |
| `SCANOPY_DAEMON_API_KEY` | UI → Generate Key | API key for authentication |
| `SCANOPY_USER_ID` | UI → Generate Key | UUID of the user who created the key |
| `SCANOPY_NAME` | Manual | Display name in the UI |
| `SCANOPY_MODE` | Manual | `Pull` (recommended) or `Push` |

## Step 9: Update Sealed Secret with Daemon API Key

After getting the API key from the UI, update your sealed secret:

```bash
cat << EOF > /tmp/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: scanopy-secrets
  namespace: scanopy
type: Opaque
stringData:
  POSTGRES_PASSWORD: "your-postgres-password"
  SCANOPY_DAEMON_API_KEY: "c77bce838fd24a12b22f6bff01b6619c"
EOF

kubeseal --format=yaml < /tmp/secret.yaml > apps/scanopy/secret-sealed.yaml
rm /tmp/secret.yaml
kubectl apply -f apps/scanopy/secret-sealed.yaml
```

## Step 10: Apply and Verify

```bash
# Apply all manifests
kubectl apply -k apps/scanopy/

# Restart daemon to pick up new config
kubectl rollout restart deployment scanopy-daemon -n scanopy

# Check daemon logs
kubectl logs -n scanopy deployment/scanopy-daemon
```

**Successful output looks like:**
```
INFO daemon: 🤖 Scanopy Daemon v0.12.9
INFO daemon: 🔗 Server at http://server.scanopy.svc.cluster.local:60072
INFO daemon: Network ID available: 252286e7-b169-49d8-916a-1380f5241cef
INFO daemon: API key available: [redacted]
INFO scanopy::daemon::runtime::service: Successfully registered with server
INFO daemon: Daemon running in Pull mode
INFO scanopy::daemon::discovery::manager: Discovery completed successfully
```

---

## Troubleshooting

### Daemon fails to register

**Symptoms:**
```
ERROR: Failed to register with server
```

**Solutions:**
1. Verify `SCANOPY_NETWORK_ID` matches the UUID from "Generate Key"
2. Verify `SCANOPY_DAEMON_API_KEY` is correct
3. Check server is accessible: `kubectl exec -n scanopy deployment/scanopy-daemon -- curl http://server.scanopy.svc.cluster.local:60072`

### Wrong environment variable names

**Problem:** Using `DAEMON_API_KEY` instead of `SCANOPY_DAEMON_API_KEY`

The correct prefix is `SCANOPY_` for all daemon environment variables:
- ❌ `DAEMON_API_KEY`
- ✅ `SCANOPY_DAEMON_API_KEY`

### Daemon can't see network devices

**Problem:** Daemon only sees Kubernetes pods, not physical devices

**Solution:** Enable `hostNetwork: true` and add network capabilities:
```yaml
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
  containers:
    - securityContext:
        capabilities:
          add: [NET_ADMIN, NET_RAW]
```

### Service environment variable conflicts

**Problem:** Kubernetes injects service discovery env vars that conflict with app config

**Solution:** Disable service links:
```yaml
spec:
  enableServiceLinks: false
```

### Database connection errors

**Problem:** Server can't connect to PostgreSQL

**Solutions:**
1. Verify PostgreSQL pod is running: `kubectl get pods -n scanopy`
2. Check service name matches DATABASE_URL host
3. Verify password in sealed secret matches

### DNS resolution fails with hostNetwork

**Problem:** Daemon can't resolve Kubernetes service names

**Solution:** Use `ClusterFirstWithHostNet` DNS policy:
```yaml
spec:
  hostNetwork: true
  dnsPolicy: ClusterFirstWithHostNet
```

---

## File Structure

```
apps/scanopy/
├── namespace.yaml
├── postgresql-pvc.yaml
├── postgresql-sts.yaml
├── postgresql-svc.yaml
├── server-deployment.yaml
├── server-svc.yaml
├── daemon-deployment.yaml
├── httproute.yaml
├── secret-sealed.yaml
├── secret-template.yaml
├── kustomization.yaml
└── README.md
```

---

## Quick Reference

### Check all pods are running
```bash
kubectl get pods -n scanopy
```

### View server logs
```bash
kubectl logs -n scanopy deployment/scanopy-server
```

### View daemon logs
```bash
kubectl logs -n scanopy deployment/scanopy-daemon
```

### Restart daemon after config changes
```bash
kubectl rollout restart deployment scanopy-daemon -n scanopy
```

### Re-seal secrets
```bash
kubeseal --format=yaml < /tmp/secret.yaml > apps/scanopy/secret-sealed.yaml
```

