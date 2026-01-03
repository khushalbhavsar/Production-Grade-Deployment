#!/bin/bash
#==============================================================================
# ShopDeploy - Cleanup Script
# Cleans up Docker images, build artifacts, and temporary files
# Usage: ./cleanup.sh [level]
# Levels: soft (default), hard, full
#==============================================================================

set -e

LEVEL=${1:-soft}

# Color output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[CLEANUP]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

echo "=============================================="
echo "  ShopDeploy Cleanup"
echo "  Level: ${LEVEL}"
echo "=============================================="

#------------------------------------------------------------------------------
# Soft Cleanup - Safe cleanup operations
#------------------------------------------------------------------------------
soft_cleanup() {
    log_info "Running soft cleanup..."
    
    # Remove dangling Docker images
    docker image prune -f
    
    # Remove stopped containers
    docker container prune -f
    
    # Remove unused networks
    docker network prune -f
    
    # Remove npm cache
    npm cache clean --force 2>/dev/null || true
    
    # Remove node_modules from build directories
    find . -name "node_modules" -type d -prune -exec rm -rf {} + 2>/dev/null || true
    
    # Remove build artifacts
    find . -name "dist" -type d -prune -exec rm -rf {} + 2>/dev/null || true
    find . -name "build" -type d -prune -exec rm -rf {} + 2>/dev/null || true
    find . -name "coverage" -type d -prune -exec rm -rf {} + 2>/dev/null || true
    
    # Remove temporary files
    find . -name "*.log" -type f -delete 2>/dev/null || true
    find . -name "*.tmp" -type f -delete 2>/dev/null || true
    find . -name ".DS_Store" -type f -delete 2>/dev/null || true
    
    log_info "Soft cleanup completed"
}

#------------------------------------------------------------------------------
# Hard Cleanup - More aggressive cleanup
#------------------------------------------------------------------------------
hard_cleanup() {
    soft_cleanup
    
    log_info "Running hard cleanup..."
    
    # Remove all ShopDeploy images
    docker images | grep shopdeploy | awk '{print $3}' | xargs docker rmi -f 2>/dev/null || true
    
    # Remove all unused images
    docker image prune -a -f
    
    # Remove all unused volumes
    docker volume prune -f
    
    # Clean Terraform cache
    find . -name ".terraform" -type d -prune -exec rm -rf {} + 2>/dev/null || true
    find . -name "*.tfstate.backup" -type f -delete 2>/dev/null || true
    find . -name "tfplan*" -type f -delete 2>/dev/null || true
    
    log_info "Hard cleanup completed"
}

#------------------------------------------------------------------------------
# Full Cleanup - Complete cleanup (use with caution)
#------------------------------------------------------------------------------
full_cleanup() {
    log_warn "Full cleanup will remove ALL Docker data!"
    read -p "Are you sure? (y/N): " confirm
    
    if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
        log_warn "Full cleanup cancelled"
        return
    fi
    
    hard_cleanup
    
    log_info "Running full cleanup..."
    
    # Remove ALL Docker data
    docker system prune -a -f --volumes
    
    # Remove all Helm releases in shopdeploy namespace
    helm ls -n shopdeploy -q | xargs -r helm uninstall -n shopdeploy 2>/dev/null || true
    
    # Delete Kubernetes namespace (will delete all resources)
    kubectl delete namespace shopdeploy 2>/dev/null || true
    
    log_info "Full cleanup completed"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
case ${LEVEL} in
    soft)
        soft_cleanup
        ;;
    hard)
        hard_cleanup
        ;;
    full)
        full_cleanup
        ;;
    *)
        log_warn "Unknown level: ${LEVEL}. Use: soft, hard, or full"
        exit 1
        ;;
esac

echo ""
log_info "Cleanup completed!"

# Show current Docker usage
echo ""
log_info "Current Docker disk usage:"
docker system df
