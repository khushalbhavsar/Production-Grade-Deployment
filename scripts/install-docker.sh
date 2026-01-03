#!/bin/bash
#==============================================================================
# ShopDeploy - Docker Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
# Also supports Ubuntu/Debian as fallback
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
echo "  Installing Docker on Amazon Linux"
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

# Install Docker based on OS
if [[ "$OS" == *"Amazon Linux"* ]]; then
    log_info "Installing Docker for Amazon Linux..."
    
    # Check if Amazon Linux 2023
    if [[ "$VER" == "2023" ]] || [[ -f /etc/amazon-linux-release ]]; then
        log_info "Detected Amazon Linux 2023"
        
        # Install Docker on Amazon Linux 2023
        sudo dnf update -y
        sudo dnf install -y docker
        
    else
        log_info "Detected Amazon Linux 2"
        
        # Install Docker on Amazon Linux 2
        sudo yum update -y
        sudo amazon-linux-extras install docker -y 2>/dev/null || sudo yum install -y docker
    fi
    
    # Enable and start Docker service
    sudo systemctl enable docker
    sudo systemctl start docker
    
    # Install Docker Compose v2 (standalone)
    log_info "Installing Docker Compose..."
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    
    # Also install as docker plugin
    sudo mkdir -p /usr/local/lib/docker/cli-plugins
    sudo curl -SL "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/lib/docker/cli-plugins/docker-compose
    sudo chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

elif [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    log_info "Installing Docker for Ubuntu/Debian..."
    
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
    
    # Add Docker GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
        https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

else
    log_error "Unsupported OS: $OS"
    log_info "Attempting generic installation..."
    
    # Generic fallback for RHEL-based systems
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    sudo systemctl enable docker
    sudo systemctl start docker
fi

# Add users to docker group
log_info "Configuring user permissions..."
sudo usermod -aG docker $USER 2>/dev/null || true
sudo usermod -aG docker ec2-user 2>/dev/null || true
sudo usermod -aG docker jenkins 2>/dev/null || true

# Verify Docker is running
log_info "Verifying Docker installation..."
sudo systemctl status docker --no-pager || true

echo ""
echo "=============================================="
echo "  Docker Installation Complete!"
echo "=============================================="
echo ""
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version 2>/dev/null || docker compose version 2>/dev/null)"
echo ""
log_warn "IMPORTANT: Log out and log back in for group changes to take effect!"
log_info "Or run: newgrp docker"
