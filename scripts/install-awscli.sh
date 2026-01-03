#!/bin/bash
#==============================================================================
# ShopDeploy - AWS CLI Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Installs AWS CLI v2 and eksctl
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
echo "  Installing AWS CLI v2 on Amazon Linux"
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

# Check if AWS CLI is already installed
if command -v aws &> /dev/null; then
    CURRENT_VERSION=$(aws --version 2>&1 | awk '{print $1}' | cut -d'/' -f2)
    log_info "AWS CLI already installed: $CURRENT_VERSION"
    log_info "Checking for updates..."
fi

# Install prerequisites
log_info "Installing prerequisites..."
if [[ "$OS" == *"Amazon Linux"* ]]; then
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        sudo dnf install -y unzip curl gzip tar
    else
        sudo yum install -y unzip curl gzip tar
    fi
else
    sudo apt-get update && sudo apt-get install -y unzip curl
fi

# Remove old AWS CLI v1 if present
if command -v aws &> /dev/null; then
    if aws --version 2>&1 | grep -q "aws-cli/1"; then
        log_warn "Removing AWS CLI v1..."
        sudo rm -f /usr/bin/aws
        sudo rm -f /usr/bin/aws_completer
        sudo rm -rf /usr/local/aws
    fi
fi

# Remove existing AWS CLI v2 installation for clean update
log_info "Preparing for fresh installation..."
sudo rm -rf /usr/local/aws-cli 2>/dev/null || true
sudo rm -f /usr/local/bin/aws 2>/dev/null || true
sudo rm -f /usr/local/bin/aws_completer 2>/dev/null || true

# Download and install AWS CLI v2
log_info "Downloading AWS CLI v2..."
cd /tmp
curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"

log_info "Installing AWS CLI v2..."
unzip -o -q awscliv2.zip
sudo ./aws/install --update

# Cleanup
rm -rf aws awscliv2.zip

# Configure CLI autocompletion
log_info "Configuring AWS CLI autocompletion..."

# Add to bashrc if not already present
if ! grep -q "aws_completer" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# AWS CLI autocompletion
complete -C '/usr/local/bin/aws_completer' aws
EOF
fi

# Add to system-wide profile
if [ -d /etc/profile.d ]; then
    sudo tee /etc/profile.d/aws-cli.sh > /dev/null << 'EOF'
# AWS CLI autocompletion for all users
if [ -f /usr/local/bin/aws_completer ]; then
    complete -C '/usr/local/bin/aws_completer' aws
fi
EOF
    sudo chmod +x /etc/profile.d/aws-cli.sh
fi

echo ""
echo "=============================================="
echo "  Installing eksctl (EKS CLI)"
echo "=============================================="

# Install eksctl
log_info "Installing eksctl..."
ARCH=amd64
PLATFORM=$(uname -s)_$ARCH

curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${PLATFORM}.tar.gz"
tar -xzf "eksctl_${PLATFORM}.tar.gz" -C /tmp
sudo mv /tmp/eksctl /usr/local/bin/
sudo chmod +x /usr/local/bin/eksctl
rm -f "eksctl_${PLATFORM}.tar.gz"

# Configure eksctl autocompletion
if ! grep -q "eksctl completion bash" ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'EOF'

# eksctl autocompletion
source <(eksctl completion bash)
EOF
fi

echo ""
echo "=============================================="
echo "  Installing Session Manager Plugin"
echo "=============================================="

# Install Session Manager Plugin (useful for EKS)
log_info "Installing AWS Session Manager Plugin..."
cd /tmp
if [[ "$OS" == *"Amazon Linux"* ]]; then
    curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/linux_64bit/session-manager-plugin.rpm" -o "session-manager-plugin.rpm"
    sudo yum install -y session-manager-plugin.rpm 2>/dev/null || sudo dnf install -y session-manager-plugin.rpm 2>/dev/null || log_warn "Session Manager plugin installation skipped"
    rm -f session-manager-plugin.rpm
elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    curl -fsSL "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"
    sudo dpkg -i session-manager-plugin.deb 2>/dev/null || log_warn "Session Manager plugin installation skipped"
    rm -f session-manager-plugin.deb
fi

echo ""
echo "=============================================="
echo "  Installation Complete!"
echo "=============================================="
echo ""
log_info "AWS CLI version:"
aws --version
echo ""
log_info "eksctl version:"
eksctl version 2>/dev/null || log_warn "eksctl not installed"
echo ""
log_info "Session Manager Plugin:"
session-manager-plugin --version 2>/dev/null || log_warn "Session Manager plugin not installed"
echo ""
echo "=============================================="
log_info "Configure AWS credentials using one of these methods:"
echo ""
echo "  Method 1: Interactive configuration"
echo "    aws configure"
echo ""
echo "  Method 2: Environment variables"
echo "    export AWS_ACCESS_KEY_ID=<your-key>"
echo "    export AWS_SECRET_ACCESS_KEY=<your-secret>"
echo "    export AWS_DEFAULT_REGION=us-east-1"
echo ""
echo "  Method 3: IAM Role (recommended for EC2)"
echo "    Attach an IAM role to your EC2 instance"
echo ""
log_info "Verify configuration:"
echo "    aws sts get-caller-identity"
echo ""
log_warn "Run 'source ~/.bashrc' to enable autocompletion in current session."
