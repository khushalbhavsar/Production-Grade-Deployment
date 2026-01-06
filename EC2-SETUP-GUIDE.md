# 🚀 EC2 Instance Complete Setup Guide

This comprehensive guide walks you through setting up an AWS EC2 instance from scratch, including all package installations, Jenkins CI/CD pipeline creation, and monitoring dashboard setup with Grafana & Prometheus.

---

## 📋 Table of Contents

1. [EC2 Instance Launch](#1-ec2-instance-launch)
2. [Connect to EC2 Instance](#2-connect-to-ec2-instance)
3. [System Update & Basic Utilities](#3-system-update--basic-utilities)
4. [Install Docker](#4-install-docker)
5. [Install AWS CLI](#5-install-aws-cli)
6. [Install kubectl](#6-install-kubectl)
7. [EKS Cluster Creation & Deletion](#61-eks-cluster-creation--deletion)
8. [Install Helm](#7-install-helm)
9. [Install Jenkins](#8-install-jenkins)
10. [Jenkins Pipeline Configuration](#9-jenkins-pipeline-configuration)
11. [Install Monitoring Stack](#10-install-monitoring-stack)
12. [Grafana Dashboard Creation](#11-grafana-dashboard-creation)
13. [Security Group Configuration](#12-security-group-configuration)
14. [Quick Installation Scripts](#13-quick-installation-scripts)
15. [Troubleshooting](#14-troubleshooting)

---

## 1. EC2 Instance Launch

### Recommended Instance Configuration

| Setting | Value |
|---------|-------|
| **AMI** | Amazon Linux 2023 |
| **Instance Type** | t3.large (2 vCPU, 8 GB RAM) |
| **Storage** | 30 GB gp3 SSD |
| **Key Pair** | Create new or use existing (.pem) |

### Launch Steps

1. **Go to AWS Console** → EC2 → Launch Instance

2. **Name and Tags**
   ```
   Name: ShopEasy-DevOps-Server
   ```

3. **Select AMI**
   - Choose **Amazon Linux 2023 AMI** (64-bit x86)

4. **Instance Type**
   - Select `t3.large` (minimum for Jenkins + Monitoring)

5. **Key Pair**
   ```bash
   # Create new key pair: shopdeploy-key
   # Download .pem file and keep it safe
   ```

6. **Network Settings**
   - Allow SSH (22) from your IP
   - Allow HTTP (80) from Anywhere
   - Allow Custom TCP (8080) from Anywhere - Jenkins
   - Allow Custom TCP (3000) from Anywhere - Grafana
   - Allow Custom TCP (9090) from Anywhere - Prometheus

7. **Storage**
   - 30 GiB gp3 root volume

8. **Launch Instance**

---

## 2. Connect to EC2 Instance

### Using SSH (Linux/Mac/WSL)

```bash
# Set proper permissions for key file
chmod 400 shopdeploy-key.pem

# Connect to instance
ssh -i "shopdeploy-key.pem" ec2-user@<YOUR-EC2-PUBLIC-IP>
```

### Using PuTTY (Windows)

1. Convert .pem to .ppk using PuTTYgen
2. Open PuTTY → Enter Host: `ec2-user@<EC2-PUBLIC-IP>`
3. Go to Connection → SSH → Auth → Browse .ppk file
4. Click Open

### Verify Connection

```bash
# Check system info
uname -a
cat /etc/os-release
```

---

## 3. System Update & Basic Utilities

```bash
# Update system packages
sudo dnf update -y

# Install essential utilities
sudo dnf install -y git wget unzip jq tree htop vim tar gzip nc bind-utils iputils

# Verify installations
git --version
```

---

## 4. Install Docker

```bash
#==============================================================================
# Step 1: Install Docker
#==============================================================================
sudo dnf install -y docker

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker

# Verify Docker installation
docker --version

#==============================================================================
# Step 2: Add current user to Docker group
#==============================================================================
sudo usermod -aG docker $USER

# Apply group changes (logout/login or use newgrp)
newgrp docker

# Verify Docker works without sudo
docker run hello-world

#==============================================================================
# Step 3: Install Docker Compose
#==============================================================================
DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
    -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# Verify Docker Compose
docker-compose --version
```

---

## 5. Install AWS CLI

```bash
#==============================================================================
# Install AWS CLI v2
#==============================================================================
cd /tmp

# Download AWS CLI
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

# Unzip and install
unzip awscliv2.zip
sudo ./aws/install

# Verify installation
aws --version

# Clean up
rm -rf aws awscliv2.zip

#==============================================================================
# Configure AWS CLI
#==============================================================================
aws configure
# Enter:
#   - AWS Access Key ID
#   - AWS Secret Access Key
#   - Default region: us-east-1 (or your preferred region)
#   - Output format: json

# Verify configuration
aws sts get-caller-identity
```

---

## 6. Install kubectl

```bash
#==============================================================================
# Install kubectl (Kubernetes CLI)
#==============================================================================

# Get latest stable version
KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)

cd /tmp

# Download kubectl
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# Download checksum
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

# Verify checksum
echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check

# Install kubectl
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Verify installation
kubectl version --client

# Clean up
rm kubectl kubectl.sha256

#==============================================================================
# Configure kubectl autocompletion
#==============================================================================
echo 'source <(kubectl completion bash)' >> ~/.bashrc
echo 'alias k=kubectl' >> ~/.bashrc
echo 'complete -o default -F __start_kubectl k' >> ~/.bashrc
source ~/.bashrc

#==============================================================================
# Configure EKS access (if using EKS)
#==============================================================================
aws eks update-kubeconfig \
    --region us-east-1 \
    --name shopeasy-dev-cluster  # Update with your cluster name

# Verify cluster access
kubectl get nodes
kubectl cluster-info
```

---

## 6.1. EKS Cluster Creation & Deletion

### Prerequisites

```bash
#==============================================================================
# Install eksctl (EKS CLI Tool)
#==============================================================================
# Download and install eksctl
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Verify installation
eksctl version

# Enable autocompletion
echo 'source <(eksctl completion bash)' >> ~/.bashrc
source ~/.bashrc
```

### Create EKS Cluster

#### Option 1: Using eksctl (Recommended)

```bash
#==============================================================================
# Create EKS Cluster for ShopEasy Project
#==============================================================================
eksctl create cluster \
    --name shopeasy-dev-cluster \
    --region us-east-1 \
    --version 1.28 \
    --nodegroup-name shopeasy-nodes \
    --node-type t3.medium \
    --nodes 2 \
    --nodes-min 1 \
    --nodes-max 4 \
    --managed \
    --with-oidc \
    --ssh-access \
    --ssh-public-key shopeasy-key \
    --zones us-east-1a,us-east-1b

# This command will take 15-20 minutes to complete
```

#### Option 2: Using eksctl with Config File

```bash
# Create cluster config file
cat > shopeasy-cluster.yaml <<EOF
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: shopeasy-dev-cluster
  region: us-east-1
  version: "1.28"

iam:
  withOIDC: true

managedNodeGroups:
  - name: shopeasy-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 4
    volumeSize: 30
    volumeType: gp3
    ssh:
      allow: true
      publicKeyName: shopeasy-key
    labels:
      role: worker
      environment: dev
    tags:
      Project: ShopEasy
      Environment: Development
    iam:
      withAddonPolicies:
        imageBuilder: true
        autoScaler: true
        cloudWatch: true
        albIngress: true

cloudWatch:
  clusterLogging:
    enableTypes: ["api", "audit", "authenticator", "controllerManager", "scheduler"]
EOF

# Create cluster using config file
eksctl create cluster -f shopeasy-cluster.yaml
```

#### Option 3: Using AWS CLI

```bash
#==============================================================================
# Create EKS Cluster using AWS CLI
#==============================================================================

# Step 1: Create IAM Role for EKS Cluster
aws iam create-role \
    --role-name ShopEasyEKSClusterRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "eks.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam attach-role-policy \
    --role-name ShopEasyEKSClusterRole \
    --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy

# Step 2: Create VPC (or use existing)
# Get default VPC and subnets
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query 'Vpcs[0].VpcId' --output text)
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text | tr '\t' ',')

# Step 3: Create EKS Cluster
aws eks create-cluster \
    --name shopeasy-dev-cluster \
    --region us-east-1 \
    --kubernetes-version 1.28 \
    --role-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ShopEasyEKSClusterRole \
    --resources-vpc-config subnetIds=$SUBNET_IDS

# Wait for cluster to be active (takes ~10 minutes)
aws eks wait cluster-active --name shopeasy-dev-cluster --region us-east-1

# Step 4: Create Node Group
aws iam create-role \
    --role-name ShopEasyEKSNodeRole \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

aws iam attach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam attach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam attach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly

aws eks create-nodegroup \
    --cluster-name shopeasy-dev-cluster \
    --nodegroup-name shopeasy-nodes \
    --node-role arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/ShopEasyEKSNodeRole \
    --subnets $(echo $SUBNET_IDS | tr ',' ' ') \
    --instance-types t3.medium \
    --scaling-config minSize=1,maxSize=4,desiredSize=2 \
    --disk-size 30

# Wait for nodegroup to be active
aws eks wait nodegroup-active \
    --cluster-name shopeasy-dev-cluster \
    --nodegroup-name shopeasy-nodes \
    --region us-east-1
```

### Verify Cluster Creation

```bash
#==============================================================================
# Verify EKS Cluster
#==============================================================================

# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name shopeasy-dev-cluster

# Check cluster info
kubectl cluster-info

# Check nodes
kubectl get nodes -o wide

# Check system pods
kubectl get pods -n kube-system

# Check cluster details
eksctl get cluster --name shopeasy-dev-cluster --region us-east-1
aws eks describe-cluster --name shopeasy-dev-cluster --region us-east-1
```

### Delete EKS Cluster

#### Option 1: Using eksctl (Recommended)

```bash
#==============================================================================
# Delete EKS Cluster using eksctl
#==============================================================================

# Delete all resources deployed on the cluster first
kubectl delete all --all -n default
kubectl delete all --all -n monitoring
kubectl delete all --all -n argocd

# Delete the cluster (this deletes nodegroups and all associated resources)
eksctl delete cluster --name shopeasy-dev-cluster --region us-east-1

# This will take 10-15 minutes to complete
```

#### Option 2: Using eksctl with Config File

```bash
# If you created using config file
eksctl delete cluster -f shopeasy-cluster.yaml
```

#### Option 3: Using AWS CLI

```bash
#==============================================================================
# Delete EKS Cluster using AWS CLI
#==============================================================================

# Step 1: Delete Node Group
aws eks delete-nodegroup \
    --cluster-name shopeasy-dev-cluster \
    --nodegroup-name shopeasy-nodes \
    --region us-east-1

# Wait for nodegroup deletion
aws eks wait nodegroup-deleted \
    --cluster-name shopeasy-dev-cluster \
    --nodegroup-name shopeasy-nodes \
    --region us-east-1

# Step 2: Delete Cluster
aws eks delete-cluster \
    --name shopeasy-dev-cluster \
    --region us-east-1

# Wait for cluster deletion
aws eks wait cluster-deleted --name shopeasy-dev-cluster --region us-east-1

# Step 3: Clean up IAM Roles (optional)
aws iam detach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy
aws iam detach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy
aws iam detach-role-policy --role-name ShopEasyEKSNodeRole --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly
aws iam delete-role --role-name ShopEasyEKSNodeRole

aws iam detach-role-policy --role-name ShopEasyEKSClusterRole --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy
aws iam delete-role --role-name ShopEasyEKSClusterRole

echo "✅ EKS Cluster deleted successfully!"
```

### Quick Reference Commands

```bash
#==============================================================================
# EKS Cluster Management Quick Reference
#==============================================================================

# List all clusters
eksctl get cluster --region us-east-1
aws eks list-clusters --region us-east-1

# Describe cluster
eksctl get cluster --name shopeasy-dev-cluster --region us-east-1
aws eks describe-cluster --name shopeasy-dev-cluster --region us-east-1

# List nodegroups
eksctl get nodegroup --cluster shopeasy-dev-cluster --region us-east-1
aws eks list-nodegroups --cluster-name shopeasy-dev-cluster --region us-east-1

# Scale nodegroup
eksctl scale nodegroup \
    --cluster shopeasy-dev-cluster \
    --name shopeasy-nodes \
    --nodes 3 \
    --nodes-min 2 \
    --nodes-max 5 \
    --region us-east-1

# Update cluster version
eksctl upgrade cluster --name shopeasy-dev-cluster --region us-east-1

# Add new nodegroup
eksctl create nodegroup \
    --cluster shopeasy-dev-cluster \
    --name shopeasy-nodes-v2 \
    --node-type t3.large \
    --nodes 2 \
    --region us-east-1

# Delete specific nodegroup
eksctl delete nodegroup \
    --cluster shopeasy-dev-cluster \
    --name shopeasy-nodes-v2 \
    --region us-east-1
```

---

## 7. Install Helm

```bash
#==============================================================================
# Install Helm (Kubernetes Package Manager)
#==============================================================================

# Method 1: Official script (recommended)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version

#==============================================================================
# Configure Helm autocompletion
#==============================================================================
echo 'source <(helm completion bash)' >> ~/.bashrc
source ~/.bashrc

#==============================================================================
# Add common Helm repositories
#==============================================================================
helm repo add stable https://charts.helm.sh/stable
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add argo https://argoproj.github.io/argo-helm

# Update repositories
helm repo update

# List repositories
helm repo list
```

---

## 8. Install Jenkins

```bash
#==============================================================================
# Step 1: Install Java 21 (Amazon Corretto)
#==============================================================================
sudo dnf install -y java-21-amazon-corretto

# Verify Java
java --version

# Set JAVA_HOME
JAVA_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "export JAVA_HOME=$JAVA_PATH" >> ~/.bashrc
source ~/.bashrc

#==============================================================================
# Step 2: Install Maven (Build Tool)
#==============================================================================
sudo dnf install -y maven

# Verify Maven
mvn -v

#==============================================================================
# Step 3: Add Jenkins Repository
#==============================================================================
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

#==============================================================================
# Step 4: Install Jenkins
#==============================================================================
sudo dnf upgrade -y
sudo dnf install -y jenkins

# Verify Jenkins version
jenkins --version

#==============================================================================
# Step 5: Add Jenkins to Docker Group
#==============================================================================
sudo usermod -aG docker jenkins

#==============================================================================
# Step 6: Start Jenkins Service
#==============================================================================
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Check Jenkins status
sudo systemctl status jenkins

#==============================================================================
# Step 7: Get Initial Admin Password
#==============================================================================
echo "=============================================="
echo "  🔐 Jenkins Initial Admin Password:"
echo "=============================================="
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Access Jenkins
echo ""
echo "  🌐 Access Jenkins at: http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8080"
```

### Jenkins Initial Setup

1. **Access Jenkins**: Open `http://<EC2-PUBLIC-IP>:8080` in browser
2. **Unlock Jenkins**: Paste the initial admin password
3. **Install Plugins**: Select "Install suggested plugins"
4. **Create Admin User**: Set up your admin credentials
5. **Configure URL**: Set Jenkins URL to `http://<EC2-PUBLIC-IP>:8080/`

---

## 9. Jenkins Pipeline Configuration

### Step 1: Install Required Plugins

Go to **Manage Jenkins** → **Plugins** → **Available plugins** and install:

| Plugin | Purpose |
|--------|---------|
| Docker Pipeline | Docker build/push integration |
| Docker | Docker support |
| Git | Git repository support |
| GitHub | GitHub integration |
| Pipeline | Pipeline support |
| Blue Ocean | Modern UI (optional) |
| Kubernetes CLI | kubectl integration |

### Step 2: Configure Credentials

Go to **Manage Jenkins** → **Credentials** → **System** → **Global credentials**:

#### Docker Hub Credentials

```
Kind: Username with password
ID: docker-hub-credentials
Username: <your-dockerhub-username>
Password: <your-dockerhub-token>
```

#### Kubeconfig (for K8s deployment)

```
Kind: Secret file
ID: kubeconfig
File: Upload your kubeconfig file
```

### Step 3: Create Pipeline Job

1. **New Item** → Enter name: `shopeasy-pipeline`
2. **Select**: Pipeline → OK
3. **Configure Pipeline**:

```groovy
pipeline {
    agent any
    
    environment {
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_IMAGE = 'khushalbhavsar/multibranch-flask-app'  // Update with your DockerHub username
        DOCKER_CREDENTIALS_ID = 'docker-hub-credentials'
        APP_NAME = 'shopeasy'
        APP_PORT = '5000'
        KUBECONFIG_CREDENTIALS_ID = 'kubeconfig'
        K8S_NAMESPACE = 'default'
        BUILD_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT?.take(7) ?: 'latest'}"
    }
    
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.GIT_COMMIT_SHORT = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                    echo "Building commit: ${env.GIT_COMMIT_SHORT}"
                }
            }
        }
        
        stage('Setup Python') {
            steps {
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r src/requirements.txt
                '''
            }
        }
        
        stage('Code Quality') {
            parallel {
                stage('Lint') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            pip install flake8 pylint
                            flake8 src/ --max-line-length=120 || true
                        '''
                    }
                }
                stage('Security Scan') {
                    steps {
                        sh '''
                            . venv/bin/activate
                            pip install bandit safety
                            bandit -r src/ -ll || true
                        '''
                    }
                }
            }
        }
        
        stage('Unit Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    pip install pytest pytest-cov
                    pytest tests/ -v --cov=src --cov-report=xml
                '''
            }
        }
        
        stage('Build Docker Image') {
            steps {
                script {
                    docker.build("${DOCKER_IMAGE}:${BUILD_TAG}", "-f docker/Dockerfile .")
                    docker.build("${DOCKER_IMAGE}:latest", "-f docker/Dockerfile .")
                }
            }
        }
        
        stage('Push Docker Image') {
            when {
                branch 'main'
            }
            steps {
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDENTIALS_ID) {
                        docker.image("${DOCKER_IMAGE}:${BUILD_TAG}").push()
                        docker.image("${DOCKER_IMAGE}:latest").push()
                    }
                }
            }
        }
        
        stage('Deploy to Kubernetes') {
            when {
                branch 'main'
            }
            steps {
                withCredentials([file(credentialsId: KUBECONFIG_CREDENTIALS_ID, variable: 'KUBECONFIG')]) {
                    sh '''
                        sed -i "s|image:.*|image: ${DOCKER_IMAGE}:${BUILD_TAG}|g" k8s/deployment.yaml
                        kubectl apply -f k8s/deployment.yaml -n ${K8S_NAMESPACE}
                        kubectl apply -f k8s/service.yaml -n ${K8S_NAMESPACE}
                        kubectl rollout status deployment/${APP_NAME}-app -n ${K8S_NAMESPACE} --timeout=300s
                    '''
                }
            }
        }
    }
    
    post {
        always {
            sh "docker rmi ${DOCKER_IMAGE}:${BUILD_TAG} || true"
            cleanWs()
        }
        success {
            echo "✅ Pipeline completed successfully!"
        }
        failure {
            echo "❌ Pipeline failed!"
        }
    }
}
```

### Step 4: Create Multibranch Pipeline (Recommended)

1. **New Item** → Enter name: `shopeasy-multibranch`
2. **Select**: Multibranch Pipeline → OK
3. **Branch Sources** → Add source → GitHub
4. **Configure**:
   - Repository URL: `https://github.com/khushalbhavsar/Production-Grade-Deployment.git`
   - Credentials: Add GitHub credentials
   - Behaviors: Discover branches
5. **Build Configuration**:
   - Mode: by Jenkinsfile
   - Script Path: `ci/Jenkinsfile`

---

## 10. Install Monitoring Stack

### Option A: Standalone Installation (EC2 Native)

```bash
#==============================================================================
# Step 1: Install Grafana
#==============================================================================
sudo dnf install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-12.2.1-1.x86_64.rpm

# Start Grafana
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

# Verify Grafana
sudo systemctl status grafana-server

#==============================================================================
# Step 2: Install Prometheus
#==============================================================================
PROMETHEUS_VERSION="3.5.0"
cd /tmp

# Download Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz

# Extract
tar -xvf prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz
cd prometheus-${PROMETHEUS_VERSION}.linux-amd64

# Create prometheus user
sudo useradd --no-create-home --shell /bin/false prometheus

# Copy binaries
sudo cp prometheus /usr/local/bin/
sudo cp promtool /usr/local/bin/

# Create directories
sudo mkdir -p /etc/prometheus
sudo mkdir -p /var/lib/prometheus

# Copy configuration files
sudo cp prometheus.yml /etc/prometheus/
sudo cp -r consoles /etc/prometheus/
sudo cp -r console_libraries /etc/prometheus/

# Set ownership
sudo chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
sudo chown prometheus:prometheus /usr/local/bin/prometheus
sudo chown prometheus:prometheus /usr/local/bin/promtool

#==============================================================================
# Step 3: Create Prometheus Service
#==============================================================================
sudo tee /etc/systemd/system/prometheus.service > /dev/null <<EOF
[Unit]
Description=Prometheus Monitoring
Wants=network-online.target
After=network-online.target

[Service]
User=prometheus
Group=prometheus
Type=simple
ExecStart=/usr/local/bin/prometheus \\
  --config.file=/etc/prometheus/prometheus.yml \\
  --storage.tsdb.path=/var/lib/prometheus \\
  --web.console.templates=/etc/prometheus/consoles \\
  --web.console.libraries=/etc/prometheus/console_libraries

[Install]
WantedBy=multi-user.target
EOF

# Start Prometheus
sudo systemctl daemon-reload
sudo systemctl start prometheus
sudo systemctl enable prometheus

#==============================================================================
# Step 4: Install Node Exporter
#==============================================================================
NODE_EXPORTER_VERSION="1.10.2"
cd /tmp

wget https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz

tar xvf node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz
cd node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64

sudo cp node_exporter /usr/local/bin
sudo useradd node_exporter --no-create-home --shell /bin/false
sudo chown node_exporter:node_exporter /usr/local/bin/node_exporter

# Create Node Exporter service
sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOF
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl start node_exporter
sudo systemctl enable node_exporter

#==============================================================================
# Step 5: Configure Prometheus Targets
#==============================================================================
sudo tee /etc/prometheus/prometheus.yml > /dev/null <<EOF
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']

  - job_name: 'jenkins'
    metrics_path: '/prometheus'
    static_configs:
      - targets: ['localhost:8080']

  - job_name: 'shopeasy'
    metrics_path: '/metrics'
    static_configs:
      - targets: ['localhost:5000']
EOF

sudo systemctl restart prometheus

#==============================================================================
# Verify Services
#==============================================================================
echo "=============================================="
echo "  📊 Monitoring Stack Status"
echo "=============================================="
systemctl is-active grafana-server && echo "✅ Grafana: Running" || echo "❌ Grafana: Not Running"
systemctl is-active prometheus && echo "✅ Prometheus: Running" || echo "❌ Prometheus: Not Running"
systemctl is-active node_exporter && echo "✅ Node Exporter: Running" || echo "❌ Node Exporter: Not Running"

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo ""
echo "  🌐 Access URLs:"
echo "  Grafana:     http://${PUBLIC_IP}:3000 (admin/admin)"
echo "  Prometheus:  http://${PUBLIC_IP}:9090"
echo "  Node Metrics: http://${PUBLIC_IP}:9100/metrics"
```

### Option B: Kubernetes Installation (Helm)

```bash
#==============================================================================
# Install on Kubernetes using Helm
#==============================================================================

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
    -n monitoring \
    --set server.persistentVolume.size=10Gi \
    --set alertmanager.persistentVolume.size=2Gi

# Install Grafana
helm install grafana grafana/grafana \
    -n monitoring \
    --set persistence.enabled=true \
    --set persistence.size=5Gi \
    --set service.type=LoadBalancer

# Get Grafana admin password
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 -d ; echo

# Get Grafana service URL
kubectl get svc -n monitoring grafana

# Verify pods
kubectl get pods -n monitoring
```

---

## 11. Grafana Dashboard Creation

### Step 1: Access Grafana

1. Open `http://<EC2-PUBLIC-IP>:3000`
2. Login with `admin` / `admin`
3. Change password when prompted

### Step 2: Add Prometheus Data Source

1. Go to **⚙️ Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure:
   ```
   Name: Prometheus
   URL: http://localhost:9090
   ```
5. Click **Save & Test**

### Step 3: Import Pre-built Dashboards

1. Go to **➕** → **Import**
2. Enter Dashboard ID and click **Load**:

| Dashboard | ID | Description | Status |
|-----------|-----|-------------|--------|
| **Node Exporter Full** | `1860` | Complete Linux/system metrics (CPU, Memory, Disk, Network) | ✅ Verified - Active (Rev 42) |
| **Prometheus 2.0 Overview** | `3662` | Prometheus self-monitoring and performance | ✅ Verified - Works with Prometheus 2.x |
| **Jenkins Performance & Health** | `9964` | Jenkins job queues, executors, JVM metrics | ✅ Verified - Requires Prometheus Plugin |
| **Docker & System Monitoring** | `893` | Docker host and container metrics | ⚠️ Older (Grafana 4) - Use for cAdvisor |

**Recommended Additional Dashboards:**

| Dashboard | ID | Description | Status |
|-----------|-----|-------------|--------|
| **Kubernetes Cluster** | `7249` | K8s cluster-wide metrics | ✅ For K8s deployments |
| **Kubernetes Pods** | `6417` | Pod-level monitoring | ✅ For K8s deployments |
| **Kubernetes Deployment** | `8588` | Deployment metrics | ✅ For K8s deployments |

3. Select **Prometheus** as data source
4. Click **Import**

> **Note:** For Jenkins monitoring, install the [Prometheus Plugin](https://plugins.jenkins.io/prometheus/) in Jenkins first. Configure it at **Manage Jenkins** → **Configure System** → **Prometheus** section.

### Step 4: Create Custom Application Dashboard

1. **Create** → **Dashboard** → **Add visualization**
2. Select **Prometheus** data source
3. Add panels for:

**Panel 1: Application Requests**
```promql
rate(http_requests_total{job="shopeasy"}[5m])
```

**Panel 2: Response Time**
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="shopeasy"}[5m]))
```

**Panel 3: Error Rate**
```promql
rate(http_requests_total{job="shopeasy", status=~"5.."}[5m])
```

**Panel 4: CPU Usage**
```promql
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

**Panel 5: Memory Usage**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

**Panel 6: Disk Usage**
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

### Step 5: Configure Alerts

1. Go to **Alerting** → **Alert rules** → **Create alert rule**
2. Create alerts for:

**High CPU Alert**
```promql
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
```

**High Memory Alert**
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
```

**Disk Space Alert**
```promql
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100) > 90
```

---

## 12. Security Group Configuration

Ensure your EC2 security group has these inbound rules:

| Type | Port | Source | Purpose |
|------|------|--------|---------|
| SSH | 22 | Your IP | SSH access |
| HTTP | 80 | 0.0.0.0/0 | Web traffic |
| HTTPS | 443 | 0.0.0.0/0 | Secure web traffic |
| Custom TCP | 8080 | 0.0.0.0/0 | Jenkins |
| Custom TCP | 3000 | 0.0.0.0/0 | Grafana |
| Custom TCP | 9090 | 0.0.0.0/0 | Prometheus |
| Custom TCP | 9100 | 0.0.0.0/0 | Node Exporter |
| Custom TCP | 5000 | 0.0.0.0/0 | Application |

```bash
# Using AWS CLI to add rules
aws ec2 authorize-security-group-ingress \
    --group-id sg-xxxxxxxxx \
    --protocol tcp \
    --port 8080 \
    --cidr 0.0.0.0/0
```

---

## 13. Quick Installation Scripts

### One-Click Bootstrap Script

```bash
# Clone repository and run bootstrap
git clone https://github.com/khushalbhavsar/Production-Grade-Deployment.git
cd Production-Grade-Deployment/scripts

# Run complete bootstrap
chmod +x ec2-bootstrap.sh
sudo ./ec2-bootstrap.sh
```

### Individual Installation Scripts

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Install Docker
./scripts/install-docker.sh

# Install kubectl
./scripts/install-kubectl.sh

# Install Helm
./scripts/install-helm.sh

# Install Jenkins
sudo ./scripts/install-jenkins.sh

# Install Monitoring Stack
sudo ./scripts/install-grafana-prometheus.sh
```

---

## 14. Troubleshooting

### Jenkins Issues

```bash
# Check Jenkins logs
sudo journalctl -u jenkins -f

# Restart Jenkins
sudo systemctl restart jenkins

# Check Jenkins status
sudo systemctl status jenkins

# Get initial password again
sudo cat /var/lib/jenkins/secrets/initialAdminPassword

# Fix Docker permission issues
sudo usermod -aG docker jenkins
sudo systemctl restart jenkins
```

### Grafana Issues

```bash
# Check Grafana logs
sudo journalctl -u grafana-server -f

# Restart Grafana
sudo systemctl restart grafana-server

# Check Grafana status
sudo systemctl status grafana-server

# Reset admin password
sudo grafana-cli admin reset-admin-password newpassword
```

### Prometheus Issues

```bash
# Check Prometheus logs
sudo journalctl -u prometheus -f

# Validate configuration
/usr/local/bin/promtool check config /etc/prometheus/prometheus.yml

# Restart Prometheus
sudo systemctl restart prometheus

# Check targets
curl http://localhost:9090/api/v1/targets
```

### Docker Issues

```bash
# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker

# Check Docker logs
sudo journalctl -u docker -f

# Clean up Docker resources
docker system prune -af
```

### Network/Firewall Issues

```bash
# Check if port is listening
sudo netstat -tlnp | grep :8080

# Check firewall status
sudo firewall-cmd --list-all

# Open port in firewall
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload

# Check security group from inside instance
curl -s http://169.254.169.254/latest/meta-data/security-groups
```

---

## 📚 Quick Reference

### Service URLs

| Service | Port | URL |
|---------|------|-----|
| Jenkins | 8080 | `http://<EC2-IP>:8080` |
| Grafana | 3000 | `http://<EC2-IP>:3000` |
| Prometheus | 9090 | `http://<EC2-IP>:9090` |
| Node Exporter | 9100 | `http://<EC2-IP>:9100` |
| Application | 5000 | `http://<EC2-IP>:5000` |

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | admin (change on first login) |
| Jenkins | admin | From `/var/lib/jenkins/secrets/initialAdminPassword` |

### Service Commands

```bash
# Start services
sudo systemctl start jenkins grafana-server prometheus node_exporter

# Stop services
sudo systemctl stop jenkins grafana-server prometheus node_exporter

# Restart services
sudo systemctl restart jenkins grafana-server prometheus node_exporter

# Check status
sudo systemctl status jenkins grafana-server prometheus node_exporter
```

---

## ✅ Setup Checklist

- [ ] EC2 instance launched with correct specs
- [ ] Security group configured with required ports
- [ ] System updated and utilities installed
- [ ] Docker installed and configured
- [ ] AWS CLI installed and configured
- [ ] kubectl installed and configured
- [ ] Helm installed with repositories added
- [ ] Jenkins installed and initial setup complete
- [ ] Jenkins plugins installed
- [ ] Jenkins credentials configured
- [ ] Jenkins pipeline created
- [ ] Prometheus installed and running
- [ ] Grafana installed and running
- [ ] Node Exporter installed and running
- [ ] Grafana data source configured
- [ ] Dashboards imported/created
- [ ] Alerts configured

---

## 📞 Support

For issues or questions:
- Check the [Troubleshooting](#14-troubleshooting) section
- Review logs using `journalctl -u <service-name>`
- Open an issue in the project repository: [Production-Grade-Deployment](https://github.com/khushalbhavsar/Production-Grade-Deployment)

---

## 📌 Project-Specific Information

| Item | Value |
|------|-------|
| **Application Name** | ShopEasy (E-commerce Flask App) |
| **Docker Image** | `khushalbhavsar/multibranch-flask-app` |
| **Container Port** | 5000 |
| **K8s Deployment** | `shopeasy-app` |
| **K8s Service** | `shopeasy-service` |
| **Namespace** | `default` |
| **Health Endpoint** | `/health` |
| **GitOps Tool** | Argo CD |
| **Repository** | `https://github.com/khushalbhavsar/Production-Grade-Deployment.git` |

---

*Last Updated: January 2026*
