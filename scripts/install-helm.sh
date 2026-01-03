#!/bin/bash
#==============================================================================
# ShopDeploy - Helm Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Installs Helm (Kubernetes Package Manager)
#==============================================================================

# Continue on error to complete as much as possible
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo "=============================================="
echo "  Installing Helm on Amazon Linux"
echo "=============================================="

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
    echo "Detected OS: $OS $VER"
}

detect_os

HELM_VERSION="${1:-}"

# Install using official Helm installation script (works on all Linux)
log_info "Downloading and installing Helm..."

# Method 1: Official script (recommended)
curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
if ! command -v helm &> /dev/null; then
    log_warn "Official script installation failed, trying manual installation..."
    
    # Method 2: Manual installation fallback
    cd /tmp
    
    # Get latest version if not specified
    if [ -z "$HELM_VERSION" ]; then
        HELM_VERSION=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    fi
    
    log_info "Downloading Helm ${HELM_VERSION}..."
    wget -q "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz"
    
    tar -zxvf "helm-${HELM_VERSION}-linux-amd64.tar.gz"
    sudo mv linux-amd64/helm /usr/local/bin/helm
    sudo chmod +x /usr/local/bin/helm
    
    # Cleanup
    rm -rf linux-amd64 "helm-${HELM_VERSION}-linux-amd64.tar.gz"
fi

# Configure Helm autocompletion
log_info "Configuring Helm autocompletion..."

# Add to bashrc if not already present
if ! grep -q "helm completion bash" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# helm autocompletion
source <(helm completion bash)
EOF
fi

# Add to system-wide profile (optional)
if [ -d /etc/profile.d ]; then
    sudo tee /etc/profile.d/helm.sh > /dev/null << 'EOF'
# helm autocompletion for all users
if command -v helm &> /dev/null; then
    source <(helm completion bash)
fi
EOF
    sudo chmod +x /etc/profile.d/helm.sh
fi

# Add common Helm repositories
log_info "Adding common Helm repositories..."
helm repo add stable https://charts.helm.sh/stable 2>/dev/null || log_warn "stable repo may already exist"
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || log_warn "bitnami repo may already exist"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>/dev/null || log_warn "prometheus-community repo may already exist"
helm repo add grafana https://grafana.github.io/helm-charts 2>/dev/null || log_warn "grafana repo may already exist"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 2>/dev/null || log_warn "ingress-nginx repo may already exist"
helm repo add jetstack https://charts.jetstack.io 2>/dev/null || log_warn "jetstack repo may already exist"
helm repo add aws-ebs-csi-driver https://kubernetes-sigs.github.io/aws-ebs-csi-driver 2>/dev/null || log_warn "aws-ebs-csi-driver repo may already exist"

log_info "Updating Helm repositories..."
helm repo update

echo ""
echo "=============================================="
echo "  Helm Installation Complete!"
echo "=============================================="
echo ""
helm version
echo ""
log_info "Installed Helm repositories:"
helm repo list
echo ""
log_info "Helm is ready to use!"
echo ""
log_info "Common commands:"
echo "  helm search repo <chart>     - Search for charts"
echo "  helm install <name> <chart>  - Install a chart"
echo "  helm list                    - List installed releases"
echo "  helm upgrade <name> <chart>  - Upgrade a release"
echo ""
log_warn "Run 'source ~/.bashrc' to enable autocompletion in current session."
