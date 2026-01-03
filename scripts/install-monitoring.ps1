#==============================================================================
# ShopDeploy - Monitoring Stack Installation Script for Windows
# Installs Prometheus and Grafana on Kubernetes using Helm
#==============================================================================

param(
    [Parameter(Mandatory=$false)]
    [string]$Namespace = 'monitoring',
    
    [Parameter(Mandatory=$false)]
    [string]$GrafanaPassword = '',
    
    [Parameter(Mandatory=$false)]
    [string]$SlackWebhookUrl = '',
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  ShopDeploy - Monitoring Stack Installation" -ForegroundColor Cyan
Write-Host "  Namespace: $Namespace" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Generate random password if not provided
if (-not $GrafanaPassword) {
    Add-Type -AssemblyName System.Web
    $GrafanaPassword = [System.Web.Security.Membership]::GeneratePassword(16, 2)
    Write-Host "[INFO] Generated Grafana admin password" -ForegroundColor Yellow
}

#------------------------------------------------------------------------------
# Add Helm Repositories
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Adding Helm repositories..." -ForegroundColor Green

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts 2>$null
helm repo add grafana https://grafana.github.io/helm-charts 2>$null
helm repo update

#------------------------------------------------------------------------------
# Create Namespace
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Creating monitoring namespace..." -ForegroundColor Green

$namespaceYaml = @"
apiVersion: v1
kind: Namespace
metadata:
  name: $Namespace
"@

$namespaceYaml | kubectl apply -f -

#------------------------------------------------------------------------------
# Install Prometheus
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Installing Prometheus..." -ForegroundColor Green

$prometheusValuesFile = Join-Path $ProjectRoot "monitoring\prometheus-values.yaml"

$prometheusArgs = @(
    'upgrade', '--install', 'prometheus', 'prometheus-community/prometheus',
    '--namespace', $Namespace,
    '--values', $prometheusValuesFile,
    '--wait',
    '--timeout', '10m'
)

if ($SlackWebhookUrl) {
    $prometheusArgs += '--set', "alertmanager.config.global.slack_api_url=$SlackWebhookUrl"
}

if ($DryRun) {
    $prometheusArgs += '--dry-run', '--debug'
}

Write-Host "[CMD] helm $($prometheusArgs -join ' ')" -ForegroundColor DarkGray
& helm @prometheusArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Prometheus installation failed" -ForegroundColor Red
    exit 1
}

#------------------------------------------------------------------------------
# Install Grafana
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Installing Grafana..." -ForegroundColor Green

$grafanaValuesFile = Join-Path $ProjectRoot "monitoring\grafana-values.yaml"

$grafanaArgs = @(
    'upgrade', '--install', 'grafana', 'grafana/grafana',
    '--namespace', $Namespace,
    '--values', $grafanaValuesFile,
    '--set', "adminPassword=$GrafanaPassword",
    '--wait',
    '--timeout', '10m'
)

if ($DryRun) {
    $grafanaArgs += '--dry-run', '--debug'
}

Write-Host "[CMD] helm $($grafanaArgs -join ' ')" -ForegroundColor DarkGray
& helm @grafanaArgs

if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Grafana installation failed" -ForegroundColor Red
    exit 1
}

#------------------------------------------------------------------------------
# Install ShopDeploy Dashboard
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Installing ShopDeploy Grafana dashboard..." -ForegroundColor Green

$dashboardFile = Join-Path $ProjectRoot "monitoring\dashboards\shopdeploy-dashboard.json"

if (Test-Path $dashboardFile) {
    kubectl create configmap shopdeploy-dashboard `
        --from-file=$dashboardFile `
        --namespace $Namespace `
        --dry-run=client -o yaml | kubectl apply -f -
    
    kubectl label configmap shopdeploy-dashboard grafana_dashboard=1 -n $Namespace --overwrite
}

#------------------------------------------------------------------------------
# Install Metrics Server (if not installed)
#------------------------------------------------------------------------------
Write-Host "`n[INFO] Checking Metrics Server..." -ForegroundColor Green

$metricsServer = kubectl get deployment metrics-server -n kube-system 2>$null
if (-not $metricsServer) {
    Write-Host "[INFO] Installing Metrics Server..." -ForegroundColor Yellow
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
}

#------------------------------------------------------------------------------
# Output Access Information
#------------------------------------------------------------------------------
Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  Monitoring Stack Installed!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan

if (-not $DryRun) {
    Write-Host "`n[INFO] Access Information:" -ForegroundColor Yellow
    
    # Grafana URL
    Write-Host "`nGrafana:" -ForegroundColor Green
    Write-Host "  Username: admin" -ForegroundColor White
    Write-Host "  Password: $GrafanaPassword" -ForegroundColor White
    
    # Port forward instructions
    Write-Host "`nTo access Grafana locally, run:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward svc/grafana 3000:80 -n $Namespace" -ForegroundColor White
    Write-Host "  Then open: http://localhost:3000" -ForegroundColor White
    
    Write-Host "`nTo access Prometheus locally, run:" -ForegroundColor Yellow
    Write-Host "  kubectl port-forward svc/prometheus-server 9090:80 -n $Namespace" -ForegroundColor White
    Write-Host "  Then open: http://localhost:9090" -ForegroundColor White
    
    # Show all pods
    Write-Host "`n[INFO] Monitoring pods:" -ForegroundColor Yellow
    kubectl get pods -n $Namespace
    
    # Show services
    Write-Host "`n[INFO] Monitoring services:" -ForegroundColor Yellow
    kubectl get svc -n $Namespace
}

# Save password to file (for reference)
$credentialsFile = Join-Path $ProjectRoot ".grafana-credentials"
@"
Grafana Credentials
===================
Namespace: $Namespace
Username: admin
Password: $GrafanaPassword

Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

IMPORTANT: Delete this file after noting the credentials!
"@ | Out-File -FilePath $credentialsFile -Encoding UTF8

Write-Host "`n[INFO] Credentials saved to: $credentialsFile" -ForegroundColor Magenta
Write-Host "[WARN] Delete this file after noting the credentials!" -ForegroundColor Red
