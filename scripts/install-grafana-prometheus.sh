#!/bin/bash
#==============================================================================
# ShopDeploy - Grafana, Prometheus & Node Exporter Installation Script
# Optimized for Amazon Linux 2 / Amazon Linux 2023
#==============================================================================
#
# Prerequisites:
#   - AWS EC2 Instance: t3.medium or higher
#   - Security Group Ports Open:
#       * Grafana: 3000
#       * Prometheus: 9090
#       * Node Exporter: 9100
#   - Storage: 20 GB SSD minimum
#
# Usage:
#   chmod +x install-grafana-prometheus.sh
#   sudo ./install-grafana-prometheus.sh
#
#==============================================================================

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
echo "  ShopDeploy - Monitoring Stack Installation"
echo "  Grafana + Prometheus + Node Exporter"
echo "=============================================="

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    log_error "Please run this script with sudo or as root"
    exit 1
fi

#==============================================================================
# Step 1: Update System and Install Dependencies
#==============================================================================
log_step "Step 1: Updating system and installing dependencies..."

yum update -y
yum install wget tar make -y
log_info "System updated and dependencies installed!"

#==============================================================================
# Step 2: Install Grafana Server
#==============================================================================
log_step "Step 2: Installing Grafana Enterprise..."

# Install Grafana Enterprise 12.2.1
yum install -y https://dl.grafana.com/enterprise/release/grafana-enterprise-12.2.1-1.x86_64.rpm

# Start Grafana service
systemctl start grafana-server
systemctl enable grafana-server

# Verify installation
grafana-server --version 2>/dev/null || log_info "Grafana installed"
log_info "Grafana installed and started!"

#==============================================================================
# Step 3: Install Prometheus
#==============================================================================
log_step "Step 3: Installing Prometheus..."

PROMETHEUS_VERSION="3.5.0"
cd /tmp

# Download Prometheus
if [ ! -f "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz" ]; then
    wget "https://github.com/prometheus/prometheus/releases/download/v${PROMETHEUS_VERSION}/prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
fi

# Extract and setup
tar -xvf "prometheus-${PROMETHEUS_VERSION}.linux-amd64.tar.gz"
cd "prometheus-${PROMETHEUS_VERSION}.linux-amd64"

# Create prometheus user
if ! id -u prometheus &>/dev/null; then
    useradd --no-create-home --shell /bin/false prometheus
fi

# Copy binaries
cp prometheus /usr/local/bin/
cp promtool /usr/local/bin/

# Create directories
mkdir -p /etc/prometheus
mkdir -p /var/lib/prometheus

# Copy configuration
cp prometheus.yml /etc/prometheus/
cp -r consoles /etc/prometheus/ 2>/dev/null || true
cp -r console_libraries /etc/prometheus/ 2>/dev/null || true

# Set ownership
chown -R prometheus:prometheus /etc/prometheus /var/lib/prometheus
chown prometheus:prometheus /usr/local/bin/prometheus
chown prometheus:prometheus /usr/local/bin/promtool

log_info "Prometheus binaries installed!"

#==============================================================================
# Step 4: Create Prometheus Systemd Service
#==============================================================================
log_step "Step 4: Creating Prometheus systemd service..."

cat > /etc/systemd/system/prometheus.service <<EOF
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
systemctl daemon-reload
systemctl start prometheus
systemctl enable prometheus

log_info "Prometheus service created and started!"

#==============================================================================
# Step 5: Install Node Exporter
#==============================================================================
log_step "Step 5: Installing Node Exporter..."

NODE_EXPORTER_VERSION="1.10.2"
cd /tmp

# Download Node Exporter
if [ ! -f "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz" ]; then
    wget "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
fi

# Extract and setup
tar xvf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
cd "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"

# Copy binary
cp node_exporter /usr/local/bin

# Create node_exporter user
if ! id -u node_exporter &>/dev/null; then
    useradd node_exporter --no-create-home --shell /bin/false
fi

# Set ownership
chown node_exporter:node_exporter /usr/local/bin/node_exporter

log_info "Node Exporter binary installed!"

#==============================================================================
# Step 6: Create Node Exporter Systemd Service
#==============================================================================
log_step "Step 6: Creating Node Exporter systemd service..."

cat > /etc/systemd/system/node_exporter.service <<EOF
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

# Start Node Exporter
systemctl daemon-reload
systemctl start node_exporter
systemctl enable node_exporter

log_info "Node Exporter service created and started!"

#==============================================================================
# Step 7: Configure Prometheus to Scrape Node Exporter
#==============================================================================
log_step "Step 7: Configuring Prometheus scrape targets..."

# Backup original config
cp /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.backup

# Update Prometheus configuration
cat > /etc/prometheus/prometheus.yml <<EOF
# Prometheus Configuration
# Generated by install-grafana-prometheus.sh

global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files: []

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node_exporter'
    static_configs:
      - targets: ['localhost:9100']
EOF

# Set ownership
chown prometheus:prometheus /etc/prometheus/prometheus.yml

# Restart Prometheus to apply changes
systemctl restart prometheus

log_info "Prometheus configured to scrape Node Exporter!"

#==============================================================================
# Step 8: Verify All Services
#==============================================================================
log_step "Step 8: Verifying all services..."

echo ""
echo "Service Status:"
echo "---------------"

# Check Grafana
if systemctl is-active --quiet grafana-server; then
    log_info "✅ Grafana: Running"
else
    log_error "❌ Grafana: Not Running"
fi

# Check Prometheus
if systemctl is-active --quiet prometheus; then
    log_info "✅ Prometheus: Running"
else
    log_error "❌ Prometheus: Not Running"
fi

# Check Node Exporter
if systemctl is-active --quiet node_exporter; then
    log_info "✅ Node Exporter: Running"
else
    log_error "❌ Node Exporter: Not Running"
fi

#==============================================================================
# Output Access Information
#==============================================================================
echo ""
echo "=============================================="
echo "  Monitoring Stack Installation Complete!"
echo "=============================================="
echo ""

# Get instance IP
INSTANCE_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || hostname -I | awk '{print $1}')

echo "=============================================="
echo "  📊 Access URLs"
echo "=============================================="
echo ""
log_info "Grafana:"
echo "  URL: http://${INSTANCE_IP}:3000"
echo "  Username: admin"
echo "  Password: admin (change on first login)"
echo ""
log_info "Prometheus:"
echo "  URL: http://${INSTANCE_IP}:9090"
echo ""
log_info "Node Exporter Metrics:"
echo "  URL: http://${INSTANCE_IP}:9100/metrics"
echo ""

echo "=============================================="
echo "  📋 Next Steps"
echo "=============================================="
echo ""
echo "  1. Access Grafana at http://${INSTANCE_IP}:3000"
echo "  2. Login with admin/admin and change password"
echo "  3. Add Prometheus data source:"
echo "     - URL: http://localhost:9090"
echo "  4. Import dashboards from Grafana.com:"
echo "     - Node Exporter: Dashboard ID 1860"
echo "     - Prometheus: Dashboard ID 3662"
echo ""

# Cleanup
cd /tmp
rm -rf "prometheus-${PROMETHEUS_VERSION}.linux-amd64"*
rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"*

log_info "Installation complete!"
