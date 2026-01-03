# 🔄 GitOps - Continuous Deployment with Argo CD

This folder contains the **Argo CD Application** configuration for GitOps-based deployments.

---

## 📁 Structure

```
gitops/
└── argocd/
    └── application.yaml    # Argo CD Application manifest
```

---

## 🎯 What is GitOps?

GitOps is a **declarative approach** to continuous deployment where:

- 📂 **Git is the single source of truth**
- 🔄 **Automatic synchronization** between Git and Kubernetes
- 🔙 **Easy rollbacks** via Git history
- 🔍 **Drift detection** - identifies manual changes in cluster

---

## 🔄 GitOps Flow

```
┌──────────────────┐
│  Git Repository  │  ← K8s manifests stored here
│   (k8s/ folder)  │
└────────┬─────────┘
         │
         │ watches
         ▼
┌──────────────────┐
│     Argo CD      │  ← Continuously monitors Git
└────────┬─────────┘
         │
         │ syncs
         ▼
┌──────────────────┐
│  AWS EKS Cluster │  ← Applies changes automatically
└──────────────────┘
```

---

## 📋 Application Configuration

The `application.yaml` defines:

| Field | Value | Description |
|-------|-------|-------------|
| `source.repoURL` | GitHub repo URL | Where manifests are stored |
| `source.path` | `k8s` | Folder containing K8s manifests |
| `destination.server` | Kubernetes API | Target cluster |
| `syncPolicy.automated` | `true` | Enable auto-sync |
| `syncPolicy.prune` | `true` | Delete removed resources |
| `syncPolicy.selfHeal` | `true` | Revert manual changes |

---

## 🚀 Deployment Workflow

1. **Jenkins** updates image tag in `k8s/deployment.yaml`
2. **Jenkins** commits and pushes to Git
3. **Argo CD** detects the change (within ~3 minutes)
4. **Argo CD** syncs the new manifest to EKS
5. **Kubernetes** performs rolling update
6. **New pods** are deployed with zero downtime

---

## 🔧 Argo CD Features Used

- ✅ **Automated Sync** - No manual deployment needed
- ✅ **Self-Healing** - Reverts drift automatically
- ✅ **Pruning** - Removes orphaned resources
- ✅ **Revision History** - Last 5 deployments tracked

---

## 📝 Useful Commands

```bash
# Login to Argo CD
argocd login <ARGOCD_SERVER>

# Check application status
argocd app get shopeasy-app

# Manual sync (if needed)
argocd app sync shopeasy-app

# View sync history
argocd app history shopeasy-app

# Rollback to previous version
argocd app rollback shopeasy-app <REVISION>
```

---

## 🔐 Access Argo CD UI

```bash
# Get admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d

# Username: admin
# Password: (output from above)
```
