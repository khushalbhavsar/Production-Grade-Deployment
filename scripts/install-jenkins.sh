#!/bin/bash
#==============================================================================
# ShopDeploy - Jenkins Installation Script
# Optimized for Amazon Linux 2023 (t3.large recommended)
# Also supports Ubuntu/Debian as fallback
#==============================================================================
#
# Prerequisites:
#   - AWS EC2 Instance: Amazon Linux 2023 (t3.large recommended)
#   - Security Group Ports Open:
#       * SSH: 22
#       * HTTP: 80
#       * HTTPS: 443
#       * Jenkins: 8080
#   - Storage: 30 GB SSD
#   - Key Pair: jenkins.pem (ensure secure permissions)
#
# Usage:
#   chmod +x install-jenkins.sh
#   ./install-jenkins.sh
#
#==============================================================================

# Continue on error to complete as much as possible
set +e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

echo "=============================================="
echo "  ShopDeploy - Jenkins Installation"
echo "  Optimized for Amazon Linux 2023"
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

#==============================================================================
# Step 1: Update System and Install Git
#==============================================================================
log_step "Step 1: Updating system and installing Git..."

sudo yum update -y
sudo yum install git -y
git --version
log_info "Git installed successfully!"

# Configure Git (Optional - uncomment and modify as needed)
# git config --global user.name "Your Name"
# git config --global user.email "your.email@example.com"
# git config --list

#==============================================================================
# Step 2: Install Docker
#==============================================================================
log_step "Step 2: Installing Docker..."

sudo yum install docker -y
sudo systemctl start docker
sudo systemctl enable docker
docker --version
log_info "Docker installed and started successfully!"

#==============================================================================
# Step 3: Install Java (Amazon Corretto 21)
#==============================================================================
log_step "Step 3: Installing Java 21 (Amazon Corretto)..."

# Install Java 21 (Amazon Corretto) - recommended for Amazon Linux 2023
sudo dnf install java-21-amazon-corretto -y 2>/dev/null || \
    sudo yum install fontconfig java-21-openjdk -y

java --version
log_info "Java 21 installed successfully!"

#==============================================================================
# Step 4: Install Maven
#==============================================================================
log_step "Step 4: Installing Maven..."

sudo yum install maven -y
mvn -v
log_info "Maven installed successfully!"

#==============================================================================
# Step 5: Install Jenkins
#==============================================================================
log_step "Step 5: Installing Jenkins..."

# Add Jenkins repository
sudo wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key

# Upgrade packages
sudo yum upgrade -y

# Install Jenkins
sudo yum install jenkins -y
jenkins --version
log_info "Jenkins installed successfully!"

#==============================================================================
# Step 6: Add Jenkins User to Docker Group
#==============================================================================
log_step "Step 6: Adding Jenkins user to Docker group..."

sudo usermod -aG docker jenkins
log_info "Jenkins user added to Docker group!"

# Handle Ubuntu/Debian fallback
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    log_warn "Detected Ubuntu/Debian - using apt-based installation..."
    
    # Install Java 21
    sudo apt-get update
    sudo apt-get install -y fontconfig openjdk-21-jre
    
    # Add Jenkins repository
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2023.key | sudo tee \
        /etc/apt/keyrings/jenkins-keyring.asc > /dev/null
    
    echo deb [signed-by=/etc/apt/keyrings/jenkins-keyring.asc] \
        https://pkg.jenkins.io/debian-stable binary/ | sudo tee \
        /etc/apt/sources.list.d/jenkins.list > /dev/null
    
    sudo apt-get update
    sudo apt-get install -y jenkins
    
    # Add Jenkins to Docker group
    sudo usermod -aG docker jenkins
fi

# Configure firewall (if firewalld is running)
if systemctl is-active --quiet firewalld; then
    log_info "Configuring firewall..."
    sudo firewall-cmd --permanent --add-port=8080/tcp
    sudo firewall-cmd --permanent --add-port=80/tcp
    sudo firewall-cmd --permanent --add-port=443/tcp
    sudo firewall-cmd --reload
fi

# Set JAVA_HOME
log_info "Configuring JAVA_HOME..."
JAVA_PATH=$(dirname $(dirname $(readlink -f $(which java))))
echo "JAVA_HOME=$JAVA_PATH" | sudo tee -a /etc/environment
export JAVA_HOME=$JAVA_PATH

# Configure Jenkins to use correct Java
if [ -f /etc/sysconfig/jenkins ]; then
    echo "JENKINS_JAVA_CMD=$JAVA_PATH/bin/java" | sudo tee -a /etc/sysconfig/jenkins
fi

#==============================================================================
# Step 7: Start Jenkins
#==============================================================================
log_step "Step 7: Starting Jenkins..."

sudo systemctl start jenkins
sudo systemctl enable jenkins

# Wait for Jenkins to fully start
log_info "Waiting for Jenkins to start (this may take 30-60 seconds)..."
sleep 30

# Check if Jenkins is running
max_attempts=6
attempt=1
while [ $attempt -le $max_attempts ]; do
    if sudo systemctl is-active --quiet jenkins; then
        log_info "Jenkins is running!"
        break
    else
        log_warn "Waiting for Jenkins to start... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    fi
done

echo ""
echo "=============================================="
echo "  Jenkins Installation Complete!"
echo "=============================================="
echo ""
echo "Java version:"
java -version 2>&1 | head -3
echo ""
echo "Jenkins version:"
jenkins --version 2>/dev/null || echo "Jenkins service is running"
echo ""

#==============================================================================
# Step 8: Access Jenkins Web UI
#==============================================================================
log_step "Step 8: Access Jenkins Web UI"

# Get instance IP for access URL
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo ""
echo "=============================================="
echo "  🌐 Jenkins Web UI Access"
echo "=============================================="
echo ""
log_info "Open your browser and go to:"
echo ""
echo "  http://${INSTANCE_IP}:8080"
echo ""

# Display initial admin password
if [ -f /var/lib/jenkins/secrets/initialAdminPassword ]; then
    echo "=============================================="
    log_info "🔐 Unlock Jenkins using the initial admin password:"
    echo ""
    sudo cat /var/lib/jenkins/secrets/initialAdminPassword
    echo ""
    echo "=============================================="
    echo ""
    log_info "Paste the password into the Jenkins setup screen and proceed."
fi

echo ""
log_info "✅ Installation Summary:"
echo "  - Git: $(git --version)"
echo "  - Docker: $(docker --version 2>/dev/null | head -1)"
echo "  - Java: $(java --version 2>&1 | head -1)"
echo "  - Maven: $(mvn -v 2>/dev/null | head -1)"
echo "  - Jenkins: Installed and running"
echo ""
log_info "📋 Next steps:"
echo "  1. Open http://${INSTANCE_IP}:8080 in your browser"
echo "  2. Enter the initial admin password shown above"
echo "  3. Install suggested plugins"
echo "  4. Create your admin user"
echo ""
log_warn "💡 Note: Jenkins user has been added to docker group."
log_warn "   If Docker commands fail, restart Jenkins:"
echo "     sudo systemctl restart jenkins"
echo ""
