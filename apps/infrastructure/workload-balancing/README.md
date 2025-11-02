# Workload Balancing Strategy

## Current Situation

### Node Resource Usage:
- **beelink (control-plane):** 40% CPU, 68% memory - **70+ pods**
- **worker:** 46% CPU, 35% memory - **8 pods**

### Problem:
The control-plane node (beelink) is overloaded with infrastructure pods while the worker node is underutilized.

---

## Solution Strategy

### 1. **Taint Control-Plane Node** (Recommended)
Prevent non-system pods from scheduling on control-plane:

```bash
# Add taint to control-plane
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule

# This will prevent new pods from scheduling on beelink unless they have tolerations
```

**Effect:**
- ✅ New pods will automatically go to worker node
- ✅ System pods (kube-system) already have tolerations
- ✅ Existing pods remain unchanged
- ⚠️ Need to add tolerations for critical infrastructure (ArgoCD, Longhorn, Monitoring)

---

### 2. **Add Node Affinity to Media Pods**
Prefer worker node for all media server applications.

---

### 3. **Add Pod Topology Spread Constraints**
Ensure even distribution across nodes when you add more nodes in the future.

---

### 4. **Move Heavy Infrastructure Pods**
Migrate ArgoCD, Monitoring, and other heavy workloads to worker node.

---

## Implementation Steps

### Step 1: Taint Control-Plane (Do This First)

```bash
# Add NoSchedule taint to control-plane
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule

# Verify taint
kubectl describe node beelink | grep Taints
```

### Step 2: Add Tolerations to Critical Infrastructure

Critical infrastructure that SHOULD run on control-plane:
- ArgoCD (needs to survive worker node failures)
- Cert-Manager
- MetalLB Controller
- Tailscale Operator

### Step 3: Migrate Heavy Workloads to Worker

Heavy workloads that SHOULD run on worker:
- Monitoring (Prometheus, Grafana)
- Longhorn UI
- All media server apps
- Application workloads (roomio, etc.)

### Step 4: Add Node Affinity to Media Apps

All media server apps should prefer worker node.

---

## Quick Commands

### Check Current Distribution:
```bash
# Count pods per node
kubectl get pods -A -o wide --no-headers | awk '{print $8}' | sort | uniq -c

# Check resource usage
kubectl top nodes

# Check pod distribution by namespace
kubectl get pods -A -o wide | grep beelink | wc -l
kubectl get pods -A -o wide | grep worker | wc -l
```

### Apply Taint:
```bash
# Taint control-plane
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule

# Remove taint (if needed)
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule-
```

### Force Pod Migration:
```bash
# Delete pod to force rescheduling (example)
kubectl delete pod <pod-name> -n <namespace>

# For StatefulSets, scale down and up
kubectl scale sts <name> -n <namespace> --replicas=0
kubectl scale sts <name> -n <namespace> --replicas=1
```

---

## Expected Results

### After Implementation:

**beelink (control-plane):**
- Control-plane components (kube-apiserver, etcd, scheduler, controller-manager)
- ArgoCD (critical infrastructure)
- Cert-Manager
- MetalLB Controller
- Tailscale Operator
- **~20-30 pods total**
- **CPU: 20-30%, Memory: 40-50%**

**worker:**
- All media server apps (Jellyfin, Radarr, Sonarr, Tdarr, etc.)
- Monitoring (Prometheus, Grafana)
- Longhorn data plane
- Application workloads
- **~50-60 pods total**
- **CPU: 40-60%, Memory: 50-70%**

---

## Monitoring

### Check Balance:
```bash
# Node resource usage
kubectl top nodes

# Pod count per node
kubectl get pods -A -o wide --no-headers | awk '{print $8}' | sort | uniq -c

# Media namespace distribution
kubectl get pods -n media -o wide
```

### Alerts:
- Monitor node CPU/memory usage
- Alert if control-plane >70% memory
- Alert if worker >80% CPU

---

## Rollback Plan

If something goes wrong:

```bash
# Remove taint from control-plane
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule-

# Remove node affinity from media apps
# (Edit each StatefulSet/Deployment and remove affinity section)

# Restart pods to redistribute
kubectl rollout restart deployment <name> -n <namespace>
kubectl rollout restart statefulset <name> -n <namespace>
```

---

## Next Steps

1. ✅ Apply control-plane taint
2. ✅ Add node affinity to media apps
3. ✅ Add tolerations to critical infrastructure
4. ✅ Migrate heavy workloads
5. ⏭️ Monitor and adjust
6. ⏭️ Consider adding a third node for HA

