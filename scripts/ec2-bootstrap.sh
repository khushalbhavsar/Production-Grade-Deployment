#!/bin/bash
#==============================================================================
# ShopDeploy - EC2 Bootstrap Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Installs ALL required dependencies on a fresh EC2 instance
# Run as: sudo bash ec2-bootstrap.sh
#==============================================================================

# Don't exit on error - we want to continue and report failures at the end
set +e

echo "=============================================="
echo "  ShopDeploy EC2 Bootstrap Script"
echo "  Optimized for Amazon Linux"
echo "=============================================="

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Detect OS version
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
    elif [ -f /etc/amazon-linux-release ]; then
        OS="Amazon Linux"
        VER="2023"
    elif [ -f /etc/system-release ]; then
        OS=$(cat /etc/system-release | awk '{print $1}')
        VER="2"
    else
        OS=$(uname -s)
        VER=$(uname -r)
    fi
}

detect_os
echo ""
log_info "Detected OS: $OS $VER"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

#------------------------------------------------------------------------------
# System Update
#------------------------------------------------------------------------------
log_step "Step 1/8: Updating system packages..."

if [[ "$OS" == *"Amazon Linux"* ]]; then
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        sudo dnf update -y
    else
        sudo yum update -y
    fi
else
    sudo apt-get update -y && sudo apt-get upgrade -y
fi

#------------------------------------------------------------------------------
# Install Basic Utilities
#------------------------------------------------------------------------------
log_step "Step 2/8: Installing basic utilities..."

if [[ "$OS" == *"Amazon Linux"* ]]; then
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        # Amazon Linux 2023 uses curl-minimal by default which conflicts with curl
        # We install utilities without curl (curl-minimal is already present and sufficient)
        sudo dnf install -y git wget unzip jq tree htop vim tar gzip \
            nc bind-utils iputils || true
        # Verify curl functionality (curl-minimal provides curl command)
        if ! command -v curl &> /dev/null; then
            log_warn "curl not found, attempting to install with --allowerasing..."
            sudo dnf install -y --allowerasing curl || log_warn "Could not install curl, using curl-minimal"
        fi
    else
        sudo yum install -y git curl wget unzip jq tree htop vim tar gzip \
            nc telnet bind-utils
    fi
else
    sudo apt-get install -y git curl wget unzip jq tree htop vim tar gzip \
        netcat-openbsd dnsutils
fi

#------------------------------------------------------------------------------
# Install Docker
#------------------------------------------------------------------------------
log_step "Step 3/8: Installing Docker..."
chmod +x ./install-docker.sh
./install-docker.sh

#------------------------------------------------------------------------------
# Install Jenkins
#------------------------------------------------------------------------------
log_step "Step 4/8: Installing Jenkins..."
chmod +x ./install-jenkins.sh
./install-jenkins.sh

#------------------------------------------------------------------------------
# Install Terraform
#------------------------------------------------------------------------------
log_step "Step 5/8: Installing Terraform..."
chmod +x ./install-terraform.sh
./install-terraform.sh

#------------------------------------------------------------------------------
# Install kubectl
#------------------------------------------------------------------------------
log_step "Step 6/8: Installing kubectl..."
chmod +x ./install-kubectl.sh
./install-kubectl.sh

#------------------------------------------------------------------------------
# Install Helm
#------------------------------------------------------------------------------
log_step "Step 7/8: Installing Helm..."
chmod +x ./install-helm.sh
./install-helm.sh

#------------------------------------------------------------------------------
# Install AWS CLI
#------------------------------------------------------------------------------
log_step "Step 8/8: Installing AWS CLI..."
chmod +x ./install-awscli.sh
./install-awscli.sh

#------------------------------------------------------------------------------
# Install Node.js (for build tools)
#------------------------------------------------------------------------------
log_info "Installing Node.js 18.x..."

if [[ "$OS" == *"Amazon Linux"* ]]; then
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        # Amazon Linux 2023
        sudo dnf install -y nodejs npm
    else
        # Amazon Linux 2
        curl -fsSL https://rpm.nodesource.com/setup_18.x | sudo bash -
        sudo yum install -y nodejs
    fi
else
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

#------------------------------------------------------------------------------
# Configure Jenkins User
#------------------------------------------------------------------------------
log_info "Configuring Jenkins user permissions..."
sudo usermod -aG docker jenkins 2>/dev/null || true
sudo usermod -aG docker ec2-user 2>/dev/null || true

#------------------------------------------------------------------------------
# Start Services
#------------------------------------------------------------------------------
log_info "Starting and enabling services..."
sudo systemctl enable docker
sudo systemctl start docker
sudo systemctl enable jenkins
sudo systemctl start jenkins

#------------------------------------------------------------------------------
# Configure Firewall (if firewalld is running)
#------------------------------------------------------------------------------
if systemctl is-active --quiet firewalld 2>/dev/null; then
    log_info "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=8080/tcp  # Jenkins
    sudo firewall-cmd --permanent --add-port=3000/tcp  # Grafana
    sudo firewall-cmd --permanent --add-port=9090/tcp  # Prometheus
    sudo firewall-cmd --permanent --add-port=9000/tcp  # SonarQube
    sudo firewall-cmd --reload
fi

#------------------------------------------------------------------------------
# Verify Installations
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Installation Verification"
echo "=============================================="

verify_tool() {
    local name=$1
    local cmd=$2
    if command -v $cmd &> /dev/null; then
        echo -e "${GREEN}✓${NC} $name: $($cmd --version 2>&1 | head -1)"
    else
        echo -e "${RED}✗${NC} $name: NOT INSTALLED"
    fi
}

echo ""
verify_tool "Docker" "docker"
verify_tool "Docker Compose" "docker-compose"
echo -n "  Jenkins: "
if systemctl is-active --quiet jenkins; then
    echo -e "${GREEN}Running${NC}"
else
    echo -e "${YELLOW}Not running${NC}"
fi
verify_tool "Terraform" "terraform"
verify_tool "kubectl" "kubectl"
verify_tool "Helm" "helm"
verify_tool "AWS CLI" "aws"
verify_tool "eksctl" "eksctl"
verify_tool "Node.js" "node"
verify_tool "npm" "npm"
verify_tool "Java" "java"

echo ""
echo "=============================================="
echo "  Bootstrap Complete!"
echo "=============================================="

# Get Jenkins initial password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo ""
    log_info "Jenkins Initial Admin Password:"
    echo "=============================================="
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "=============================================="
fi

# Get instance public IP for Jenkins access
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=============================================="
echo "  Access URLs"
echo "=============================================="
echo ""
echo "  Jenkins:     http://${INSTANCE_IP}:8080"
echo "  Grafana:     http://${INSTANCE_IP}:3000 (after installation)"
echo "  Prometheus:  http://${INSTANCE_IP}:9090 (after installation)"
echo ""

echo "=============================================="
echo "  Next Steps"
echo "=============================================="
echo ""
echo "  1. Access Jenkins at http://${INSTANCE_IP}:8080"
echo "  2. Configure AWS credentials: aws configure"
echo "  3. Set up GitHub webhooks"
echo "  4. Configure pipeline credentials in Jenkins"
echo "  5. Initialize Terraform: cd terraform && terraform init"
echo ""
log_warn "IMPORTANT: Log out and log back in for Docker group changes!"
echo ""
log_info "Or run: newgrp docker"
echo ""
