# 🚀 Production-Grade CI/CD Pipeline with Jenkins Multibranch & GitOps

**CI/CD • Docker • Kubernetes • GitOps • AWS EKS • Prometheus • Grafana**

---

## 📌 Project Overview

This project demonstrates a **production-grade CI/CD pipeline** built using **modern DevOps best practices**.  
It showcases how real-world DevOps teams automate application delivery from **feature branch development** to **live deployment on Kubernetes** using a **GitOps-based approach**.

The pipeline integrates **Jenkins Multibranch Pipelines**, **Docker**, **GitHub Pull Requests**, **Argo CD**, **AWS EKS**, and **Prometheus/Grafana (Monitoring)** to create a **scalable, automated, and observable deployment workflow**.

---

## 🎯 Key Objectives

- Implement **feature branch–based development**
- Use **Pull Request (PR) driven CI/CD workflow**
- Automate builds using **Jenkins Multibranch Pipeline**
- Containerize applications using **Docker**
- Push images to **DockerHub**
- Deploy applications to **AWS EKS**
- Use **Argo CD for GitOps-based Continuous Deployment**
- Monitor with **Prometheus & Grafana**
- Enable **zero-touch deployments** after merge to `main`

---

## 🔁 End-to-End CI/CD & GitOps Flow

```text
Developer
    ↓
Feature Branch (featureA / featureB)
    ↓
Pull Request → Merge to main (GitHub UI)
    ↓
Jenkins Multibranch Pipeline (CI)
    ↓
Docker Image Build & Push to DockerHub
    ↓
Update Image Tag in Git (Kubernetes Manifests)
    ↓
Argo CD Sync (GitOps)
    ↓
AWS EKS Deployment
    ↓
Prometheus Scrapes Metrics → Grafana Dashboards
    ↓
LoadBalancer URL → Live Application
```

---

## 🛠️ Tools & Technologies

| Tool | Purpose |
|------|---------|
| GitHub | Source control, feature branches & PR workflow |
| Jenkins (Multibranch Pipeline) | Continuous Integration (CI) |
| Docker | Application containerization |
| DockerHub | Container image registry |
| Kubernetes (AWS EKS) | Container orchestration |
| Argo CD | GitOps-based Continuous Deployment |
| **Prometheus** | Metrics collection & alerting |
| **Grafana** | Observability & dashboards |
| LoadBalancer Service | External access to application |

---

## 📁 Project Folder Structure

```text
Production-Grade-CICD-GitOps/
│
├── .git/
├── .gitignore
├── .dockerignore
├── README.md
├── ARCHITECTURE.md
├── COMMANDS.md
├── SETUP.md
├── .env.example
│
├── src/                          # Application Source Code
│   ├── app.py
│   └── requirements.txt
│
├── tests/                        # Automated Tests
│   └── test_app.py
│
├── docker/                       # Containerization
│   └── Dockerfile
│
├── ci/                           # CI Configuration
│   └── Jenkinsfile
│
├── k8s/                          # Kubernetes Manifests
│   ├── deployment.yaml
│   ├── service.yaml
│   └── ingress.yaml
│
├── gitops/                       # GitOps Configuration
│   └── argocd/
│       └── application.yaml
│
├── monitoring/                   # Observability Stack
│   ├── prometheus/
│   │   └── values.yaml           # Prometheus Helm values
│   └── grafana/
│       └── values.yaml           # Grafana Helm values
│
└── scripts/                      # Helper Scripts
    ├── build.sh
    ├── deploy.sh
    └── cleanup.sh
```

---

## 🔀 Branching Strategy

- `main` → Production-ready code
- `featureA`, `featureB` → Feature development branches

> ❗ Feature branches are **Git branches**, not folders.

### Workflow

1. Create feature branch
2. Commit changes
3. Raise Pull Request
4. Jenkins runs CI checks
5. Merge PR → triggers deployment

---

## 🔄 Jenkins Multibranch Pipeline

- Automatically detects:
  - New branches
  - Pull Requests
- Executes pipeline stages:
  - Checkout
  - Build
  - Test
  - Docker image build
  - Push image to DockerHub
- Runs CI **only after PR creation**
- Deploys **only after merge to `main`**

---

## 📊 Monitoring Stack (Prometheus + Grafana)

### Components

| Component | Purpose |
|-----------|---------|
| **Prometheus** | Metrics collection, alerting rules |
| **Grafana** | Visualization, dashboards, alerting |
| **kube-state-metrics** | Kubernetes object metrics |
| **node-exporter** | Node-level metrics |

### Installation via Helm

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Prometheus
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f monitoring/prometheus/values.yaml

# Install Grafana (standalone)
helm upgrade --install grafana grafana/grafana \
  --namespace monitoring \
  -f monitoring/grafana/values.yaml
```

### Pre-configured Dashboards

| Dashboard ID | Name |
|--------------|------|
| 7249 | Kubernetes Cluster Overview |
| 6417 | Kubernetes Cluster (Prometheus) |
| 1860 | Node Exporter Full |
| 8588 | Kubernetes Deployments |

### Accessing Grafana

```bash
# Get LoadBalancer URL
kubectl get svc -n monitoring grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Default credentials: admin / admin (change on first login)
```

---

## 🚀 GitOps with Argo CD

- Git is the **single source of truth**
- Kubernetes manifests are stored in Git
- Argo CD continuously watches the repository
- Any change in Git automatically syncs to EKS
- Supports:
  - Automatic deployments
  - Rollbacks
  - Drift detection

---

## ☸️ Kubernetes Deployment

- Application deployed on **AWS EKS**
- Uses:
  - Deployment
  - Service (LoadBalancer)
  - Ingress (optional)
- Application exposed externally using **LoadBalancer URL**

---

## 📋 Complete Setup Order

Follow this order for a full production deployment:

```text
1. EKS Cluster Access
   └── aws eks update-kubeconfig --name shopeasy-dev-cluster

2. Argo CD Installation
   └── kubectl create namespace argocd
   └── kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

3. Monitoring Stack
   └── helm install prometheus + grafana

4. Application Deployment
   └── Argo CD syncs from gitops/argocd/application.yaml
```

---

## 🧠 Why This Is Production-Grade

✔ Real Git branching strategy  
✔ CI and CD separation  
✔ GitOps-based deployments  
✔ Fully automated pipeline  
✔ Scalable Kubernetes architecture  
✔ **Full observability with Prometheus & Grafana**  
✔ Easy rollback and traceability  
✔ Interview and enterprise ready  

---

## 👥 Who Is This Project For?

- DevOps Beginners & Intermediate Engineers
- Jenkins Multibranch Pipeline learners
- Kubernetes & AWS EKS users
- **SRE & Monitoring enthusiasts**
- DevOps interview preparation
- CI/CD & GitOps enthusiasts

---

## 📌 Future Enhancements

- ~~Helm-based deployments~~ ✅ (Monitoring stack)
- ~~Monitoring with Prometheus & Grafana~~ ✅
- Security scanning using Trivy
- Blue-Green / Canary deployments
- Slack / Email notifications via Alertmanager

---

## ⭐ Support

If this project helped you:

- ⭐ Star the repository
- 🍴 Fork and improve it
- 📢 Share with DevOps learners

---

## 🎉 Final Note

This project is designed to reflect **real-world DevOps pipelines**, not just demo setups.  
It follows **industry best practices** used in modern production environments.

**Happy Learning & Automating! 🚀**
