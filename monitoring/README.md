# 📊 Monitoring Stack - Prometheus & Grafana

This directory contains **Helm-based configurations** for the observability stack using Prometheus and Grafana.

---

## 📁 Directory Structure

```
monitoring/
├── prometheus/
│   └── values.yaml         # Prometheus Helm values
├── grafana/
│   └── values.yaml         # Grafana Helm values
└── README.md               # This file
```

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MONITORING STACK                                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  ┌─────────────────┐    scrapes     ┌─────────────────────────────────┐    │
│  │  Node Exporter  │ ───────────────▶                                 │    │
│  └─────────────────┘                │                                 │    │
│                                     │      PROMETHEUS                 │    │
│  ┌─────────────────┐    scrapes     │      (Metrics Store)            │    │
│  │ Kube State      │ ───────────────▶                                 │    │
│  │ Metrics         │                │  - Scrapes metrics              │    │
│  └─────────────────┘                │  - Stores time-series data      │    │
│                                     │  - Evaluates alert rules        │    │
│  ┌─────────────────┐    scrapes     │                                 │    │
│  │  ShopEasy App   │ ───────────────▶                                 │    │
│  │  /metrics       │                └───────────────┬─────────────────┘    │
│  └─────────────────┘                                │                      │
│                                                     │ queries              │
│                                                     ▼                      │
│                                     ┌─────────────────────────────────┐    │
│                                     │         GRAFANA                 │    │
│                                     │      (Visualization)            │    │
│                                     │                                 │    │
│                                     │  - Dashboards                   │    │
│                                     │  - Alerts                       │    │
│                                     │  - User access                  │    │
│                                     └─────────────────────────────────┘    │
│                                                     │                      │
│                                                     ▼                      │
│                                            LoadBalancer                    │
│                                                     │                      │
└─────────────────────────────────────────────────────┼──────────────────────┘
                                                      │
                                                      ▼
                                                 [DevOps Team]
```

---

## 🚀 Installation

### Prerequisites

```bash
# Add Helm repositories
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring
```

### Install Prometheus

```bash
cd monitoring/prometheus

helm install prometheus prometheus-community/prometheus \
  -f values.yaml \
  -n monitoring

# Verify installation
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
```

### Install Grafana

```bash
cd monitoring/grafana

helm install grafana grafana/grafana \
  -f values.yaml \
  -n monitoring

# Verify installation
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
```

---

## 🔐 Access Grafana

### Get Admin Password

```bash
kubectl get secret grafana -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d
```

### Get LoadBalancer URL

```bash
kubectl get svc grafana -n monitoring
```

### Login

- **URL**: `http://<EXTERNAL-IP>`
- **Username**: `admin`
- **Password**: (from above command)

---

## 📊 Pre-configured Dashboards

The following dashboards are automatically provisioned:

| Dashboard | ID | Description |
|-----------|-----|-------------|
| Kubernetes Cluster | 7249 | Cluster-wide metrics |
| Kubernetes Pods | 6417 | Pod-level metrics |
| Node Exporter | 1860 | Node hardware metrics |
| Kubernetes Deployment | 8588 | Deployment status |

---

## 🚨 Alert Rules

### Application Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| HighErrorRate | Error rate > 10% | Critical |
| PodCrashLooping | Pod restarts frequently | Warning |
| HighMemoryUsage | Memory > 90% | Warning |

### Kubernetes Alerts

| Alert | Condition | Severity |
|-------|-----------|----------|
| NodeNotReady | Node unhealthy | Critical |
| DeploymentReplicasMismatch | Replicas don't match | Warning |

---

## 🔧 Useful Commands

```bash
# Check Prometheus targets
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Open: http://localhost:9090/targets

# Check Alertmanager
kubectl port-forward svc/prometheus-alertmanager 9093:80 -n monitoring
# Open: http://localhost:9093

# View Prometheus logs
kubectl logs -l app.kubernetes.io/name=prometheus -n monitoring

# View Grafana logs
kubectl logs -l app.kubernetes.io/name=grafana -n monitoring

# Upgrade Prometheus
helm upgrade prometheus prometheus-community/prometheus \
  -f prometheus/values.yaml -n monitoring

# Upgrade Grafana
helm upgrade grafana grafana/grafana \
  -f grafana/values.yaml -n monitoring
```

---

## 📈 Metrics Collected

### Application Metrics (ShopEasy)

- Request count by endpoint
- Response time percentiles
- Error rates
- Active connections

### Kubernetes Metrics

- Pod CPU/Memory usage
- Node resource utilization
- Deployment replica status
- Container restarts

### Node Metrics

- CPU usage
- Memory usage
- Disk I/O
- Network traffic

---

## 🎯 Best Practices

1. **Retention**: Configure appropriate retention period (default: 15 days)
2. **Storage**: Use persistent volumes for production
3. **Alerts**: Set up meaningful alerts with proper thresholds
4. **Access**: Use RBAC to control Grafana access
5. **Backup**: Regularly backup Grafana dashboards

---

## 🔗 Integration with CI/CD

The monitoring stack integrates with the CI/CD pipeline:

1. **Jenkins** builds and deploys application
2. **Argo CD** syncs to Kubernetes
3. **Prometheus** scrapes application metrics
4. **Grafana** visualizes deployment health
5. **Alertmanager** notifies on issues

---

## 📝 Troubleshooting

### Prometheus not scraping targets

```bash
# Check service discovery
kubectl port-forward svc/prometheus-server 9090:80 -n monitoring
# Navigate to Status > Service Discovery
```

### Grafana dashboard not loading

```bash
# Check data source connectivity
# Go to Configuration > Data Sources > Prometheus > Test
```

### No metrics appearing

```bash
# Verify application has /metrics endpoint
curl http://<app-service>:5000/metrics
```
