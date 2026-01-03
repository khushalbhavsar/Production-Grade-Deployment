#!/bin/bash
#==============================================================================
# ShopDeploy - kubectl Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Installs Kubernetes CLI
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
echo "  Installing kubectl on Amazon Linux"
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

# Get kubectl version (use stable if not specified)
KUBECTL_VERSION="${1:-}"
if [ -z "$KUBECTL_VERSION" ]; then
    log_info "Fetching latest stable kubectl version..."
    KUBECTL_VERSION=$(curl -L -s https://dl.k8s.io/release/stable.txt)
fi

log_info "Installing kubectl ${KUBECTL_VERSION}..."

# Create temp directory
cd /tmp

# Download kubectl binary
log_info "Downloading kubectl..."
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"

# Download checksum
log_info "Verifying checksum..."
curl -LO "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl.sha256"

# Verify checksum
if echo "$(cat kubectl.sha256)  kubectl" | sha256sum --check --status 2>/dev/null; then
    log_info "Checksum verified successfully!"
else
    log_warn "Checksum verification failed or not supported, proceeding anyway..."
fi

# Install kubectl
log_info "Installing kubectl to /usr/local/bin..."
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Cleanup
rm -f kubectl kubectl.sha256

# Configure kubectl autocompletion for bash
log_info "Configuring kubectl autocompletion..."

# Add to bashrc if not already present
if ! grep -q "kubectl completion bash" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# kubectl autocompletion
source <(kubectl completion bash)
alias k=kubectl
complete -o default -F __start_kubectl k
EOF
fi

# Add to system-wide profile (optional)
if [ -d /etc/profile.d ]; then
    sudo tee /etc/profile.d/kubectl.sh > /dev/null << 'EOF'
# kubectl autocompletion for all users
if command -v kubectl &> /dev/null; then
    source <(kubectl completion bash)
    alias k=kubectl
    complete -o default -F __start_kubectl k
fi
EOF
    sudo chmod +x /etc/profile.d/kubectl.sh
fi

# Install kubectx and kubens (optional but useful)
log_info "Installing kubectx and kubens..."
if [[ "$OS" == *"Amazon Linux"* ]]; then
    # Download and install kubectx/kubens
    sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx 2>/dev/null || true
    if [ -d /opt/kubectx ]; then
        sudo ln -sf /opt/kubectx/kubectx /usr/local/bin/kubectx 2>/dev/null || true
        sudo ln -sf /opt/kubectx/kubens /usr/local/bin/kubens 2>/dev/null || true
    fi
fi

echo ""
echo "=============================================="
echo "  kubectl Installation Complete!"
echo "=============================================="
echo ""
kubectl version --client
echo ""
log_info "kubectl is ready to use!"
echo ""
log_info "Useful aliases configured:"
echo "  k  = kubectl"
echo ""
log_info "To configure kubectl for EKS, run:"
echo "  aws eks update-kubeconfig --region <region> --name <cluster-name>"
echo ""
log_warn "Run 'source ~/.bashrc' to enable autocompletion in current session."
