#!/bin/bash
#==============================================================================
# ShopDeploy - SonarQube Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
#==============================================================================
#
# Prerequisites:
#   - AWS EC2 Instance: t2.medium / t3.medium or higher (min 4GB RAM)
#   - Security Group Ports Open:
#       * SSH: 22
#       * SonarQube: 9000
#   - Storage: 20 GB SSD
#   - Key Pair: sonar.pem (ensure secure permissions)
#
# Usage:
#   chmod +x install-sonarqube.sh
#   sudo ./install-sonarqube.sh
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
echo "  ShopDeploy - SonarQube Installation"
echo "  Optimized for Amazon Linux 2"
echo "=============================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo or as root"
    exit 1
fi

#==============================================================================
# Step 1: Update System Packages
#==============================================================================
log_step "Step 1: Updating system packages..."

yum update -y
dnf update -y 2>/dev/null || true
yum install unzip wget -y
log_info "System packages updated!"

#==============================================================================
# Step 2: Install Java 17 (Amazon Corretto)
#==============================================================================
log_step "Step 2: Installing Java 17 (Amazon Corretto)..."

yum install java-17-amazon-corretto.x86_64 -y
java --version
log_info "Java 17 installed successfully!"

#==============================================================================
# Step 3: Install PostgreSQL 15
#==============================================================================
log_step "Step 3: Installing PostgreSQL 15..."

dnf install postgresql15.x86_64 postgresql15-server -y 2>/dev/null || \
    yum install postgresql15.x86_64 postgresql15-server -y

postgresql-setup --initdb

systemctl start postgresql
systemctl enable postgresql
log_info "PostgreSQL 15 installed and started!"

#==============================================================================
# Step 4: Configure PostgreSQL User & Database
#==============================================================================
log_step "Step 4: Configuring PostgreSQL database..."

# Configure PostgreSQL authentication
PG_HBA_CONF="/var/lib/pgsql/data/pg_hba.conf"
if [ -f "$PG_HBA_CONF" ]; then
    # Backup original file
    cp "$PG_HBA_CONF" "${PG_HBA_CONF}.backup"
    
    # Update authentication method to md5 for local connections
    sed -i 's/ident/md5/g' "$PG_HBA_CONF"
    sed -i 's/peer/md5/g' "$PG_HBA_CONF"
fi

# Restart PostgreSQL to apply changes
systemctl restart postgresql

# Create database and user
sudo -u postgres psql <<EOF
ALTER USER postgres WITH PASSWORD 'Khushal@41';
CREATE DATABASE sonarqube;
CREATE USER sonar WITH ENCRYPTED PASSWORD 'Khushal@41';
GRANT ALL PRIVILEGES ON DATABASE sonarqube TO sonar;
ALTER DATABASE sonarqube OWNER TO sonar;
\q
EOF

log_info "PostgreSQL database configured!"
log_info "  Database: sonarqube"
log_info "  User: sonar"
log_info "  Password: Khushal@41"

#==============================================================================
# Step 5: Download & Setup SonarQube
#==============================================================================
log_step "Step 5: Downloading and setting up SonarQube..."

cd /opt

# Download SonarQube 10.6.0
SONAR_VERSION="10.6.0.92116"
SONAR_ZIP="sonarqube-${SONAR_VERSION}.zip"
SONAR_URL="https://binaries.sonarsource.com/Distribution/sonarqube/${SONAR_ZIP}"

if [ ! -f "$SONAR_ZIP" ]; then
    wget "$SONAR_URL"
fi

# Extract and setup
unzip -o "$SONAR_ZIP"
rm -rf sonarqube 2>/dev/null || true
mv "sonarqube-${SONAR_VERSION}" sonarqube

log_info "SonarQube ${SONAR_VERSION} downloaded and extracted!"

#==============================================================================
# Step 6: Set Kernel & OS Limits
#==============================================================================
log_step "Step 6: Setting kernel and OS limits..."

# Set vm.max_map_count
if ! grep -q "vm.max_map_count=262144" /etc/sysctl.conf; then
    echo "vm.max_map_count=262144" >> /etc/sysctl.conf
fi
sysctl -p

# Add limits for sonar user
if ! grep -q "sonar.*nofile" /etc/security/limits.conf; then
    tee -a /etc/security/limits.conf <<EOF
sonar   -   nofile   65536
sonar   -   nproc    4096
EOF
fi

log_info "Kernel and OS limits configured!"

#==============================================================================
# Step 7: Configure SonarQube Database Settings
#==============================================================================
log_step "Step 7: Configuring SonarQube database settings..."

SONAR_PROPS="/opt/sonarqube/conf/sonar.properties"

# Backup original configuration
cp "$SONAR_PROPS" "${SONAR_PROPS}.backup"

# Add database configuration
cat >> "$SONAR_PROPS" <<EOF

# Database Configuration (Added by install script)
sonar.jdbc.username=sonar
sonar.jdbc.password=Khushal@41
sonar.jdbc.url=jdbc:postgresql://localhost:5432/sonarqube
EOF

log_info "SonarQube database settings configured!"

#==============================================================================
# Step 8: Create SonarQube User
#==============================================================================
log_step "Step 8: Creating SonarQube user..."

# Create sonar user if not exists
if ! id -u sonar &>/dev/null; then
    useradd sonar
fi

chown -R sonar:sonar /opt/sonarqube
log_info "SonarQube user created and permissions set!"

#==============================================================================
# Step 9: Create Systemd Service File
#==============================================================================
log_step "Step 9: Creating systemd service file..."

cat > /etc/systemd/system/sonarqube.service <<EOF
[Unit]
Description=SonarQube LTS Service
After=network.target

[Service]
Type=forking
User=sonar
Group=sonar
LimitNOFILE=65536
LimitNPROC=4096

Environment="JAVA_HOME=/usr/lib/jvm/java-17-amazon-corretto.x86_64"
Environment="PATH=/usr/lib/jvm/java-17-amazon-corretto.x86_64/bin:/usr/local/bin:/usr/bin:/bin"

ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop

Restart=always

[Install]
WantedBy=multi-user.target
EOF

log_info "Systemd service file created!"

#==============================================================================
# Step 10: Set Permissions
#==============================================================================
log_step "Step 10: Setting permissions..."

chmod +x /opt/sonarqube/bin/linux-x86-64/sonar.sh
chmod -R 755 /opt/sonarqube/bin/
chown -R sonar:sonar /opt/sonarqube

log_info "Permissions set!"

#==============================================================================
# Step 11: Start SonarQube Service
#==============================================================================
log_step "Step 11: Starting SonarQube service..."

systemctl reset-failed sonarqube 2>/dev/null || true
systemctl daemon-reload
systemctl start sonarqube
systemctl enable sonarqube

# Wait for SonarQube to start
log_info "Waiting for SonarQube to start (this may take 1-2 minutes)..."
sleep 30

# Check if SonarQube is running
max_attempts=12
attempt=1
while [ $attempt -le $max_attempts ]; do
    if systemctl is-active --quiet sonarqube; then
        log_info "SonarQube service is running!"
        break
    else
        log_warn "Waiting for SonarQube to start... (attempt $attempt/$max_attempts)"
        sleep 10
        ((attempt++))
    fi
done

# Check service status
systemctl status sonarqube -l --no-pager

echo ""
echo "=============================================="
echo "  SonarQube Installation Complete!"
echo "=============================================="
echo ""

# Get instance IP for access URL
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo "=============================================="
echo "  💻 Access SonarQube"
echo "=============================================="
echo ""
log_info "Open in browser:"
echo ""
echo "  http://${INSTANCE_IP}:9000"
echo ""
log_info "Default credentials:"
echo "  Username: admin"
echo "  Password: admin"
echo ""
log_warn "⚠️  You will be prompted to change the password on first login"
echo ""
echo "=============================================="
echo "  📊 Database Information"
echo "=============================================="
echo ""
echo "  Database: sonarqube"
echo "  User: sonar"
echo "  Password: Khushal@41"
echo "  PostgreSQL User: postgres"
echo "  PostgreSQL Password: Khushal@41"
echo ""
log_info "📋 Next steps:"
echo "  1. Open http://${INSTANCE_IP}:9000 in your browser"
echo "  2. Login with admin/admin"
echo "  3. Change the default password"
echo "  4. Create a project and generate a token"
echo "  5. Configure Jenkins integration"
echo ""

# Check if SonarQube is accessible
log_info "Checking SonarQube accessibility..."
sleep 10
if curl -s "http://localhost:9000/api/system/status" | grep -q '"status"'; then
    log_info "✅ SonarQube is accessible!"
else
    log_warn "⚠️  SonarQube may still be starting up. Wait a few more minutes."
    log_warn "   Check logs: sudo tail -f /opt/sonarqube/logs/sonar.log"
fi
