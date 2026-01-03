# ☸️ Kubernetes Manifests

This folder contains **Kubernetes resource definitions** for deploying the ShopEasy application to AWS EKS.

---

## 📁 Files

| File | Resource Type | Description |
|------|--------------|-------------|
| `deployment.yaml` | Deployment | Application pods configuration |
| `service.yaml` | Service | LoadBalancer for external access |
| `ingress.yaml` | Ingress | Optional HTTP routing (Nginx) |

---

## 🏗️ Architecture

```
                    ┌─────────────────────────────────┐
                    │          AWS EKS Cluster         │
                    │                                  │
  Internet          │  ┌─────────────────────────┐    │
      │             │  │       Ingress           │    │
      │             │  │   (shopeasy.example.com)│    │
      ▼             │  └───────────┬─────────────┘    │
┌──────────┐        │              │                  │
│   Users  │◄───────┼──────────────┼──────────────────┤
└──────────┘        │              ▼                  │
                    │  ┌─────────────────────────┐    │
                    │  │   Service (LoadBalancer) │    │
                    │  │      Port 80 → 5000      │    │
                    │  └───────────┬─────────────┘    │
                    │              │                  │
                    │      ┌───────┼───────┐          │
                    │      ▼       ▼       ▼          │
                    │  ┌──────┐┌──────┐┌──────┐       │
                    │  │Pod 1 ││Pod 2 ││Pod 3 │       │
                    │  │:5000 ││:5000 ││:5000 │       │
                    │  └──────┘└──────┘└──────┘       │
                    │                                  │
                    └─────────────────────────────────┘
```

---

## 📋 Deployment Details

### Replicas & Strategy

| Setting | Value | Purpose |
|---------|-------|---------|
| `replicas` | 3 | High availability |
| `strategy` | RollingUpdate | Zero-downtime deployments |
| `maxSurge` | 1 | Extra pod during update |
| `maxUnavailable` | 0 | No downtime allowed |

### Resource Limits

| Resource | Request | Limit |
|----------|---------|-------|
| Memory | 128Mi | 256Mi |
| CPU | 100m | 500m |

### Health Probes

| Probe | Endpoint | Purpose |
|-------|----------|---------|
| `livenessProbe` | `/health` | Restart unhealthy pods |
| `readinessProbe` | `/health` | Traffic routing |

---

## 🌐 Service Configuration

- **Type**: `LoadBalancer`
- **External Port**: `80`
- **Target Port**: `5000`
- **Protocol**: `TCP`

This creates an **AWS ELB** (Elastic Load Balancer) automatically.

---

## 🔧 Ingress (Optional)

The ingress provides:
- Custom domain routing (`shopeasy.example.com`)
- Path-based routing
- SSL/TLS termination (with cert-manager)

> **Note**: Requires Nginx Ingress Controller installed in cluster.

---

## 🚀 Deployment Commands

```bash
# Apply all manifests
kubectl apply -f k8s/

# Check deployment status
kubectl get deployments
kubectl rollout status deployment/shopeasy-app

# Check pods
kubectl get pods -l app=shopeasy

# Check service (get LoadBalancer URL)
kubectl get svc shopeasy-service

# View pod logs
kubectl logs -l app=shopeasy --tail=100

# Scale deployment
kubectl scale deployment shopeasy-app --replicas=5

# Rollback to previous version
kubectl rollout undo deployment/shopeasy-app
```

---

## 🔍 Troubleshooting

```bash
# Describe pod for events/errors
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Execute into pod for debugging
kubectl exec -it <pod-name> -- /bin/bash

# Check endpoints
kubectl get endpoints shopeasy-service
```

---

## 📝 Image Tag Updates

The `deployment.yaml` image tag is automatically updated by Jenkins:

```yaml
image: khushalbhavsar/multibranch-flask-app:build-XX
```

This triggers Argo CD to sync and deploy the new version.
