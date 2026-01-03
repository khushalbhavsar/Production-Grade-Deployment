#==============================================================================
# ShopDeploy - Jenkins Setup Script for Windows
# Installs Jenkins on Windows using Docker or Chocolatey
#==============================================================================

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet('docker', 'chocolatey', 'standalone')]
    [string]$InstallMethod = 'docker',
    
    [Parameter(Mandatory=$false)]
    [string]$JenkinsPort = '8080'
)

$ErrorActionPreference = 'Stop'

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  ShopDeploy - Jenkins Installation" -ForegroundColor Cyan
Write-Host "  Installation Method: $InstallMethod" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

function Install-JenkinsDocker {
    Write-Host "`n[INFO] Installing Jenkins using Docker..." -ForegroundColor Green
    
    # Check if Docker is running
    try {
        docker info | Out-Null
    } catch {
        Write-Host "[ERROR] Docker is not running. Please start Docker Desktop." -ForegroundColor Red
        exit 1
    }
    
    # Create Jenkins volume
    Write-Host "[INFO] Creating Jenkins volume..." -ForegroundColor Yellow
    docker volume create jenkins_home 2>$null
    
    # Pull Jenkins image
    Write-Host "[INFO] Pulling Jenkins LTS image..." -ForegroundColor Yellow
    docker pull jenkins/jenkins:lts
    
    # Stop existing container if running
    docker stop jenkins 2>$null
    docker rm jenkins 2>$null
    
    # Run Jenkins container
    Write-Host "[INFO] Starting Jenkins container..." -ForegroundColor Yellow
    docker run -d `
        --name jenkins `
        -p ${JenkinsPort}:8080 `
        -p 50000:50000 `
        -v jenkins_home:/var/jenkins_home `
        -v /var/run/docker.sock:/var/run/docker.sock `
        --restart unless-stopped `
        jenkins/jenkins:lts
    
    Write-Host "[INFO] Waiting for Jenkins to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    # Get initial admin password
    Write-Host "`n=============================================" -ForegroundColor Cyan
    Write-Host "Jenkins Initial Admin Password:" -ForegroundColor Green
    docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
    Write-Host "=============================================" -ForegroundColor Cyan
}

function Install-JenkinsChocolatey {
    Write-Host "`n[INFO] Installing Jenkins using Chocolatey..." -ForegroundColor Green
    
    # Check if Chocolatey is installed
    if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Installing Chocolatey..." -ForegroundColor Yellow
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    }
    
    # Install Java (required for Jenkins)
    Write-Host "[INFO] Installing Java 17..." -ForegroundColor Yellow
    choco install temurin17jre -y
    
    # Install Jenkins
    Write-Host "[INFO] Installing Jenkins LTS..." -ForegroundColor Yellow
    choco install jenkins -y
    
    # Start Jenkins service
    Start-Service -Name jenkins
    
    Write-Host "[INFO] Waiting for Jenkins to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 60
    
    # Get initial admin password
    $secretPath = "C:\Program Files\Jenkins\secrets\initialAdminPassword"
    if (Test-Path $secretPath) {
        Write-Host "`n=============================================" -ForegroundColor Cyan
        Write-Host "Jenkins Initial Admin Password:" -ForegroundColor Green
        Get-Content $secretPath
        Write-Host "=============================================" -ForegroundColor Cyan
    }
}

function Install-JenkinsStandalone {
    Write-Host "`n[INFO] Installing Jenkins standalone..." -ForegroundColor Green
    
    # Download Jenkins WAR
    $jenkinsDir = "$env:USERPROFILE\jenkins"
    $jenkinsWar = "$jenkinsDir\jenkins.war"
    
    if (-not (Test-Path $jenkinsDir)) {
        New-Item -ItemType Directory -Path $jenkinsDir -Force | Out-Null
    }
    
    Write-Host "[INFO] Downloading Jenkins WAR file..." -ForegroundColor Yellow
    Invoke-WebRequest -Uri "https://get.jenkins.io/war-stable/latest/jenkins.war" -OutFile $jenkinsWar
    
    Write-Host "[INFO] Jenkins downloaded to: $jenkinsWar" -ForegroundColor Green
    Write-Host "[INFO] To start Jenkins, run:" -ForegroundColor Yellow
    Write-Host "  java -jar $jenkinsWar --httpPort=$JenkinsPort" -ForegroundColor White
}

# Execute installation based on method
switch ($InstallMethod) {
    'docker' { Install-JenkinsDocker }
    'chocolatey' { Install-JenkinsChocolatey }
    'standalone' { Install-JenkinsStandalone }
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host "  Jenkins Installation Complete!" -ForegroundColor Green
Write-Host "  Access Jenkins at: http://localhost:$JenkinsPort" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Open http://localhost:$JenkinsPort in your browser" -ForegroundColor White
Write-Host "2. Enter the initial admin password shown above" -ForegroundColor White
Write-Host "3. Install suggested plugins" -ForegroundColor White
Write-Host "4. Create an admin user" -ForegroundColor White
Write-Host "5. Configure AWS credentials" -ForegroundColor White
