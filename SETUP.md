# Setup Guide

This document provides step-by-step instructions for setting up the complete production environment.

---

## Prerequisites

| Tool | Version | Purpose |
|------|---------|---------|
| AWS CLI | v2.x | AWS resource management |

| kubectl | v1.28+ | Kubernetes management |
| Helm | v3.x | Package management |
| Docker | v24.x | Container runtime |

---

## Complete Setup Order

```text
1. AWS Configuration
   - Configure credentials & region

2. EKS Cluster Access
   - Configure kubeconfig

3. Argo CD Installation
   - GitOps deployment controller

4. Monitoring Stack
   - Prometheus & Grafana

5. Application Deployment
   - Deploy via Argo CD
```

---

## Step 1: AWS Configuration

```bash
# Configure AWS credentials
aws configure
# Enter: Access Key, Secret Key, Region (us-east-1), Output (json)

# Verify configuration
aws sts get-caller-identity
```

---

## Step 2: EKS Cluster Access

```bash
# Configure kubeconfig for dev cluster
aws eks update-kubeconfig \
  --region us-east-1 \
  --name shopeasy-dev-cluster

# Verify access
kubectl get nodes
kubectl cluster-info
```

---

## Step 3: Argo CD Installation

### Install via Helm

```bash
# Add Argo CD Helm repository
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# Create namespace
kubectl create namespace argocd

# Install Argo CD
helm install argocd argo/argo-cd -n argocd

# Verify installation
kubectl get pods -n argocd
```

### Expose Argo CD

```bash
# Patch service to LoadBalancer
kubectl patch svc argocd-server -n argocd \
  -p '{"spec": {"type": "LoadBalancer"}}'

# Get external URL
kubectl get svc argocd-server -n argocd

# Get admin password
kubectl get secret argocd-initial-admin-secret \
  -n argocd \
  -o jsonpath="{.data.password}" | base64 -d
```

### Access Argo CD

- **URL**: `https://<EXTERNAL-IP>`
- **Username**: `admin`
- **Password**: (from above command)

---

## Step 4: Monitoring Stack Installation

### Install Prometheus + Grafana

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create namespace
kubectl create namespace monitoring

# Install kube-prometheus-stack with custom values
helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring \
  -f monitoring/prometheus/values.yaml

# Install Grafana (standalone with custom dashboards)
helm upgrade --install grafana grafana/grafana \
  -n monitoring \
  -f monitoring/grafana/values.yaml
```

### Verify Installation

```bash
# Check all monitoring pods
kubectl get pods -n monitoring

# Expected pods:
# - prometheus-*
# - alertmanager-*
# - grafana-*
# - node-exporter-*
# - kube-state-metrics-*
```

### Access Grafana

```bash
# Get Grafana URL
kubectl get svc -n monitoring grafana \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Default credentials: admin / admin
# Change password on first login
```

---

## Step 5: Application Deployment via Argo CD

### Apply Argo CD Application

```bash
# Apply the application manifest
kubectl apply -f gitops/argocd/application.yaml

# Verify application in Argo CD UI
# Or via CLI:
kubectl get applications -n argocd
```

### Verify Deployment

```bash
# Check application pods
kubectl get pods -n shopeasy

# Get application URL
kubectl get svc -n shopeasy shopeasy-service
```

---

## Jenkins Server Setup (CI)

### Launch EC2 Instance

- **AMI**: Ubuntu 24.04
- **Instance Type**: t2.large
- **Security Group**: Allow ports 22, 8080, 443

### Install Jenkins

```bash
#!/bin/bash

# Install OpenJDK 17
sudo apt install openjdk-17-jre-headless -y

# Add Jenkins repository
sudo wget -O /usr/share/keyrings/jenkins-keyring.asc \
  https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key

echo deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] \
  https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
  /etc/apt/sources.list.d/jenkins.list > /dev/null

# Install Jenkins
sudo apt-get update
sudo apt-get install jenkins -y
```

### Install Docker

```bash
#!/bin/bash

# Install dependencies
sudo apt-get update
sudo apt-get install -y ca-certificates curl

# Add Docker GPG key
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add jenkins user to docker group
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Install kubectl and AWS CLI

```bash
# kubectl
curl -o kubectl https://amazon-eks.s3.us-west-2.amazonaws.com/1.19.6/2021-01-05/bin/linux/amd64/kubectl
chmod +x ./kubectl
sudo mv ./kubectl /usr/local/bin
kubectl version --short --client

# AWS CLI
sudo apt install unzip
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
aws --version
```

### Configure Jenkins kubeconfig

```bash
# Copy kubeconfig to Jenkins home
sudo mkdir -p /home/jenkins/.kube
sudo cp /root/.kube/config /home/jenkins/.kube/config
sudo chown -R jenkins:jenkins /home/jenkins/.kube
```

---

## Cleanup

### Delete Resources

```bash
# Delete Kubernetes resources first
kubectl delete -f gitops/argocd/application.yaml
helm uninstall grafana -n monitoring
helm uninstall prometheus -n monitoring
helm uninstall argocd -n argocd
```

---

## Additional Resources

- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [Prometheus Operator](https://prometheus-operator.dev/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)

