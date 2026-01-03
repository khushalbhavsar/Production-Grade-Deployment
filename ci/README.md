# 🔧 CI - Continuous Integration

This folder contains the **Jenkins Multibranch Pipeline** configuration.

---

## 📁 Files

| File | Description |
|------|-------------|
| `Jenkinsfile` | Declarative pipeline for CI/CD automation |

---

## 🔄 Jenkins Multibranch Pipeline

### What It Does

The Jenkins Multibranch Pipeline **automatically detects** and builds:
- ✅ All branches in the repository
- ✅ Pull Requests (PRs)

### Pipeline Stages

```
┌─────────────┐
│  Checkout   │  ← Clone source code
└──────┬──────┘
       ▼
┌─────────────┐
│   Install   │  ← Install Python dependencies
│    Deps     │
└──────┬──────┘
       ▼
┌─────────────┐
│  Run Tests  │  ← Execute pytest
└──────┬──────┘
       ▼
┌─────────────┐
│ Build Image │  ← Docker build (main branch only)
└──────┬──────┘
       ▼
┌─────────────┐
│ Push Image  │  ← Push to DockerHub (main branch only)
└──────┬──────┘
       ▼
┌─────────────┐
│ Update K8s  │  ← Update manifest with new image tag
│  Manifest   │     (main branch only)
└─────────────┘
```

---

## 🔐 Required Jenkins Credentials

| Credential ID | Type | Purpose |
|--------------|------|---------|
| `dockerhub-creds` | Username/Password | DockerHub authentication |
| `github-creds` | Username/Password | GitHub push access (token) |

---

## ⚙️ Environment Variables

```groovy
IMAGE_NAME = "khushalbhavsar/multibranch-flask-app"  // DockerHub image
GIT_USER   = "khushalbhavsar"                     // Git commit author
GIT_EMAIL  = "khushalbhavsar@gmail.com"           // Git commit email
```

---

## 🚀 How It Works

1. **Feature Branch Push** → Jenkins runs tests only
2. **Pull Request Created** → Jenkins runs full CI checks
3. **Merge to `main`** → Jenkins builds, pushes image, updates K8s manifest
4. **Argo CD Syncs** → Automatic deployment to Kubernetes

---

## 📝 Notes

- Pipeline runs **only on PR creation** for feature branches
- Docker build and push happen **only on `main` branch**
- Image tag format: `build-${BUILD_NUMBER}`
