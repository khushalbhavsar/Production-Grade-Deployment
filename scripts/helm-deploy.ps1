#==============================================================================
# ShopDeploy - Helm Deployment Script for Windows
# Deploy backend/frontend to Kubernetes using Helm
#==============================================================================

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('backend', 'frontend', 'all')]
    [string]$Component,
    
    [Parameter(Mandatory=$false)]
    [string]$ImageTag = 'latest',
    
    [Parameter(Mandatory=$false)]
    [ValidateSet('dev', 'staging', 'prod')]
    [string]$Environment = 'dev',
    
    [Parameter(Mandatory=$false)]
    [string]$AwsRegion = 'us-east-1',
    
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  ShopDeploy - Helm Deployment" -ForegroundColor Cyan
Write-Host "  Component: $Component" -ForegroundColor Cyan
Write-Host "  Environment: $Environment" -ForegroundColor Cyan
Write-Host "  Image Tag: $ImageTag" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# Determine namespace based on environment
$Namespace = switch ($Environment) {
    'prod' { 'shopdeploy' }
    'staging' { 'shopdeploy-staging' }
    'dev' { 'shopdeploy-dev' }
}

# Get AWS Account ID
try {
    $AwsAccountId = aws sts get-caller-identity --query Account --output text
    if (-not $AwsAccountId) {
        throw "Unable to get AWS Account ID"
    }
    Write-Host "[INFO] AWS Account ID: $AwsAccountId" -ForegroundColor Yellow
} catch {
    Write-Host "[ERROR] Failed to get AWS Account ID. Ensure AWS CLI is configured." -ForegroundColor Red
    exit 1
}

$EcrRegistry = "$AwsAccountId.dkr.ecr.$AwsRegion.amazonaws.com"

function Deploy-Component {
    param(
        [string]$ComponentName
    )
    
    $ReleaseName = "shopdeploy-$ComponentName"
    $ChartPath = Join-Path $ProjectRoot "helm\$ComponentName"
    $ValuesFile = Join-Path $ChartPath "values.yaml"
    $EnvValuesFile = Join-Path $ChartPath "values-$Environment.yaml"
    $ImageRepo = "$EcrRegistry/shopdeploy-prod-$ComponentName"
    
    Write-Host "`n[INFO] Deploying $ComponentName..." -ForegroundColor Green
    Write-Host "[INFO] Release: $ReleaseName" -ForegroundColor Yellow
    Write-Host "[INFO] Namespace: $Namespace" -ForegroundColor Yellow
    Write-Host "[INFO] Image: ${ImageRepo}:$ImageTag" -ForegroundColor Yellow
    
    # Build Helm command
    $helmArgs = @(
        'upgrade', '--install', $ReleaseName, $ChartPath,
        '--namespace', $Namespace,
        '--create-namespace',
        '--set', "image.repository=$ImageRepo",
        '--set', "image.tag=$ImageTag",
        '--values', $ValuesFile,
        '--wait',
        '--timeout', '10m'
    )
    
    # Add environment-specific values if exists
    if (Test-Path $EnvValuesFile) {
        $helmArgs += '--values', $EnvValuesFile
    }
    
    # Add dry-run flag if specified
    if ($DryRun) {
        $helmArgs += '--dry-run', '--debug'
        Write-Host "[INFO] Running in DRY-RUN mode" -ForegroundColor Magenta
    }
    
    # Execute Helm command
    Write-Host "[CMD] helm $($helmArgs -join ' ')" -ForegroundColor DarkGray
    & helm @helmArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[ERROR] Helm deployment failed for $ComponentName" -ForegroundColor Red
        exit 1
    }
    
    if (-not $DryRun) {
        Write-Host "`n[INFO] $ComponentName deployed successfully!" -ForegroundColor Green
        
        # Show deployment status
        Write-Host "`n[INFO] Deployment Status:" -ForegroundColor Yellow
        kubectl get pods -n $Namespace -l "app.kubernetes.io/name=$ComponentName"
    }
}

# Update kubeconfig for EKS
$EksClusterName = "shopdeploy-$Environment-eks"
if ($Environment -eq 'prod') {
    $EksClusterName = "shopdeploy-prod-eks"
}

Write-Host "`n[INFO] Updating kubeconfig for EKS cluster: $EksClusterName" -ForegroundColor Yellow
aws eks update-kubeconfig --region $AwsRegion --name $EksClusterName

# Deploy components
switch ($Component) {
    'backend' { 
        Deploy-Component -ComponentName 'backend' 
    }
    'frontend' { 
        Deploy-Component -ComponentName 'frontend' 
    }
    'all' {
        Deploy-Component -ComponentName 'backend'
        Deploy-Component -ComponentName 'frontend'
    }
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan

# Show all resources in namespace
if (-not $DryRun) {
    Write-Host "`n[INFO] All resources in $Namespace namespace:" -ForegroundColor Yellow
    kubectl get all -n $Namespace
}
