#!/bin/bash
#==============================================================================
# ShopDeploy - Build Script
# Builds Docker images for backend/frontend components
# Usage: ./build.sh <component> <tag>
#==============================================================================

set -e

# Configuration
COMPONENT=${1:-all}
TAG=${2:-latest}
PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[BUILD]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#------------------------------------------------------------------------------
# Build Backend Image
#------------------------------------------------------------------------------
build_backend() {
    log_info "Building Backend Docker image..."
    
    cd "${PROJECT_ROOT}/shopdeploy-backend"
    
    # Build with multi-stage optimization
    docker build \
        --tag "shopdeploy-backend:${TAG}" \
        --tag "shopdeploy-backend:latest" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="${TAG}" \
        --file Dockerfile \
        --no-cache \
        .
    
    log_info "Backend image built: shopdeploy-backend:${TAG}"
    
    # Show image size
    docker images shopdeploy-backend:${TAG} --format "Size: {{.Size}}"
}

#------------------------------------------------------------------------------
# Build Frontend Image
#------------------------------------------------------------------------------
build_frontend() {
    log_info "Building Frontend Docker image..."
    
    cd "${PROJECT_ROOT}/shopdeploy-frontend"
    
    # Build with multi-stage optimization
    docker build \
        --tag "shopdeploy-frontend:${TAG}" \
        --tag "shopdeploy-frontend:latest" \
        --build-arg BUILD_DATE="$(date -u +'%Y-%m-%dT%H:%M:%SZ')" \
        --build-arg VERSION="${TAG}" \
        --build-arg VITE_API_URL="${VITE_API_URL:-/api}" \
        --file Dockerfile \
        --no-cache \
        .
    
    log_info "Frontend image built: shopdeploy-frontend:${TAG}"
    
    # Show image size
    docker images shopdeploy-frontend:${TAG} --format "Size: {{.Size}}"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
echo "=============================================="
echo "  ShopDeploy Docker Build"
echo "  Component: ${COMPONENT}"
echo "  Tag: ${TAG}"
echo "=============================================="

case ${COMPONENT} in
    backend)
        build_backend
        ;;
    frontend)
        build_frontend
        ;;
    all)
        build_backend
        build_frontend
        ;;
    *)
        log_error "Unknown component: ${COMPONENT}. Use: backend, frontend, or all"
        ;;
esac

echo ""
log_info "Build completed successfully!"
docker images | grep shopdeploy
