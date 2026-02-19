# Quick Start: Workload Balancing

## 🎯 Goal
Balance workloads between control-plane (beelink) and worker nodes to prevent overloading.

---

## 📊 Current Situation

```
beelink (control-plane): 70+ pods, 40% CPU, 68% memory ❌ OVERLOADED
worker:                   8 pods,  46% CPU, 35% memory ✅ UNDERUTILIZED
```

---

## 🚀 Quick Start (Recommended)

### **Option 1: Fully Automated (Easiest)**

Run the interactive balancing script:

```bash
cd apps/infrastructure/workload-balancing
./balance-workload.sh
```

Then select option **2** for full automatic balancing.

This will:
1. ✅ Taint control-plane to prevent new pods
2. ✅ Add node affinity to media apps
3. ✅ Add tolerations to critical infrastructure (ArgoCD)
4. ✅ Migrate media pods to worker node
5. ✅ Show before/after status

---

### **Option 2: Manual Step-by-Step**

#### **Step 1: Taint Control-Plane**

```bash
# Prevent new pods from scheduling on control-plane
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule
```

#### **Step 2: Add Node Affinity to Media Apps**

```bash
cd apps/infrastructure/workload-balancing
./apply-node-affinity.sh
```

#### **Step 3: Restart Media Pods**

```bash
# Restart all media StatefulSets
kubectl rollout restart sts jellyfin radarr sonarr tdarr bazarr jellyseerr qbitt -n media

# Restart all media Deployments
kubectl rollout restart deployment jackett cross-seed -n media
```

#### **Step 4: Monitor**

```bash
# Watch pods migrate
watch kubectl get pods -n media -o wide

# Check node resource usage
kubectl top nodes
```

---

## 📋 What Each Step Does

### **1. Taint Control-Plane**
- **What:** Adds `NoSchedule` taint to beelink node
- **Effect:** New pods won't schedule on beelink unless they have tolerations
- **Existing pods:** Remain unchanged (not evicted)

### **2. Node Affinity**
- **What:** Adds preference for worker node to media apps
- **Effect:** Media pods will prefer worker node when scheduling
- **Fallback:** If worker is full, can still use control-plane

### **3. Tolerations**
- **What:** Allows critical infrastructure to run on control-plane
- **Effect:** ArgoCD, cert-manager, etc. can still run on beelink
- **Why:** These need to survive worker node failures

---

## 🎯 Expected Results

### **After Balancing:**

```
beelink (control-plane):
├── Control-plane components (kube-apiserver, etcd, etc.)
├── ArgoCD (critical infrastructure)
├── Cert-Manager
├── MetalLB Controller
├── Tailscale Operator
└── ~20-30 pods total
    CPU: 20-30%, Memory: 40-50% ✅

worker:
├── All media server apps
├── Monitoring (Prometheus, Grafana)
├── Longhorn data plane
├── Application workloads
└── ~50-60 pods total
    CPU: 40-60%, Memory: 50-70% ✅
```

---

## 🔍 Monitoring Commands

### **Check Pod Distribution:**
```bash
# Count pods per node
kubectl get pods -A -o wide --no-headers | awk '{print $8}' | sort | uniq -c

# Media namespace distribution
kubectl get pods -n media -o wide
```

### **Check Resource Usage:**
```bash
# Node resources
kubectl top nodes

# Pod resources in media namespace
kubectl top pods -n media --sort-by=memory
```

### **Check Taints:**
```bash
# View node taints
kubectl describe node beelink | grep Taints
kubectl describe node worker | grep Taints
```

---

## 🔄 Rollback

If something goes wrong:

### **Remove Taint:**
```bash
kubectl taint nodes beelink node-role.kubernetes.io/control-plane:NoSchedule-
```

### **Remove Node Affinity:**
```bash
# You'll need to manually edit each StatefulSet/Deployment
kubectl edit sts <name> -n media
# Remove the "affinity" section
```

### **Restart Pods:**
```bash
kubectl rollout restart sts <name> -n media
kubectl rollout restart deployment <name> -n media
```

---

## ⚠️ Important Notes

1. **Existing pods are NOT evicted** when you add a taint
   - You must manually restart them to apply new affinity rules

2. **Critical infrastructure needs tolerations**
   - ArgoCD, cert-manager, MetalLB controller should tolerate control-plane taint
   - The script adds these automatically

3. **Worker node must have enough resources**
   - Check `kubectl top nodes` before migrating
   - If worker is full, pods will remain on control-plane

4. **StatefulSets with PVCs**
   - Some pods may be tied to specific nodes due to local storage
   - Check Longhorn volume affinity if pods won't migrate

---

## 🆘 Troubleshooting

### **Pod stuck in Pending:**
```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n media

# Common causes:
# - Insufficient resources on worker node
# - PVC bound to wrong node
# - Node selector conflicts
```

### **Pod won't migrate:**
```bash
# Force delete and recreate
kubectl delete pod <pod-name> -n media --force --grace-period=0

# For StatefulSets, scale down and up
kubectl scale sts <name> -n media --replicas=0
kubectl scale sts <name> -n media --replicas=1
```

### **Check node affinity:**
```bash
# View pod's node affinity
kubectl get pod <pod-name> -n media -o yaml | grep -A 20 affinity
```

---

## 📚 Additional Resources

- [Kubernetes Taints and Tolerations](https://kubernetes.io/docs/concepts/scheduling-eviction/taint-and-toleration/)
- [Node Affinity](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)
- [Topology Spread Constraints](https://kubernetes.io/docs/concepts/scheduling-eviction/topology-spread-constraints/)

---

## 🎉 Success Criteria

You'll know it worked when:

1. ✅ `kubectl top nodes` shows balanced CPU/memory usage
2. ✅ `kubectl get pods -n media -o wide` shows most pods on worker
3. ✅ beelink memory usage drops below 50%
4. ✅ worker CPU/memory usage increases but stays below 80%
5. ✅ All media apps are running and accessible

---

## 🔮 Future Improvements

1. **Add a third node** for high availability
2. **Implement HPA** for auto-scaling media apps
3. **Use VPA** for automatic resource limit adjustments
4. **Add resource quotas** per namespace
5. **Implement pod disruption budgets** for critical apps

