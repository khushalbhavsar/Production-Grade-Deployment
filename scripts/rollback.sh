#!/bin/bash
#==============================================================================
# ShopDeploy - Rollback Script
# Rolls back Helm deployments to previous versions
# Usage: ./rollback.sh <component> <environment> [revision]
#==============================================================================

set -e

COMPONENT=${1:-all}
ENVIRONMENT=${2:-dev}
REVISION=${3:-""}

K8S_NAMESPACE="shopdeploy"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[ROLLBACK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#------------------------------------------------------------------------------
# Show Release History
#------------------------------------------------------------------------------
show_history() {
    local release=$1
    echo ""
    log_info "Release history for ${release}:"
    helm history ${release} -n ${K8S_NAMESPACE} 2>/dev/null || log_warn "No history found"
    echo ""
}

#------------------------------------------------------------------------------
# Rollback Backend
#------------------------------------------------------------------------------
rollback_backend() {
    log_info "Rolling back Backend..."
    
    show_history "shopdeploy-backend"
    
    if [ -n "${REVISION}" ]; then
        helm rollback shopdeploy-backend ${REVISION} -n ${K8S_NAMESPACE} --wait
        log_info "Backend rolled back to revision ${REVISION}"
    else
        helm rollback shopdeploy-backend -n ${K8S_NAMESPACE} --wait
        log_info "Backend rolled back to previous revision"
    fi
    
    # Verify rollback
    kubectl rollout status deployment/shopdeploy-backend -n ${K8S_NAMESPACE} --timeout=5m
}

#------------------------------------------------------------------------------
# Rollback Frontend
#------------------------------------------------------------------------------
rollback_frontend() {
    log_info "Rolling back Frontend..."
    
    show_history "shopdeploy-frontend"
    
    if [ -n "${REVISION}" ]; then
        helm rollback shopdeploy-frontend ${REVISION} -n ${K8S_NAMESPACE} --wait
        log_info "Frontend rolled back to revision ${REVISION}"
    else
        helm rollback shopdeploy-frontend -n ${K8S_NAMESPACE} --wait
        log_info "Frontend rolled back to previous revision"
    fi
    
    # Verify rollback
    kubectl rollout status deployment/shopdeploy-frontend -n ${K8S_NAMESPACE} --timeout=5m
}

#------------------------------------------------------------------------------
# Emergency Rollback (kubectl based)
#------------------------------------------------------------------------------
emergency_rollback() {
    log_warn "Emergency rollback - using kubectl rollout undo..."
    
    kubectl rollout undo deployment/shopdeploy-backend -n ${K8S_NAMESPACE} 2>/dev/null || true
    kubectl rollout undo deployment/shopdeploy-frontend -n ${K8S_NAMESPACE} 2>/dev/null || true
    
    log_info "Emergency rollback initiated"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
echo "=============================================="
echo "  ShopDeploy Rollback"
echo "  Component: ${COMPONENT}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Revision: ${REVISION:-previous}"
echo "=============================================="

# Confirm rollback
read -p "Are you sure you want to rollback? (y/N): " confirm
if [ "${confirm}" != "y" ] && [ "${confirm}" != "Y" ]; then
    log_warn "Rollback cancelled"
    exit 0
fi

case ${COMPONENT} in
    backend)
        rollback_backend
        ;;
    frontend)
        rollback_frontend
        ;;
    all)
        rollback_backend
        rollback_frontend
        ;;
    emergency)
        emergency_rollback
        ;;
    *)
        log_error "Unknown component: ${COMPONENT}. Use: backend, frontend, all, or emergency"
        ;;
esac

echo ""
log_info "Rollback completed!"

# Show current status
echo ""
log_info "Current deployment status:"
kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/part-of=shopdeploy
