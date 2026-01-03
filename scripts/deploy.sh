#!/bin/bash
#==============================================================================
# ShopDeploy - Deploy Script
# Deploys application to Kubernetes using Helm
# Usage: ./deploy.sh <component> <tag> <environment> [--canary]
#==============================================================================

set -e

COMPONENT=${1:-all}
TAG=${2:-latest}
ENVIRONMENT=${3:-dev}
CANARY=${4:-""}

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)
HELM_DIR="${PROJECT_ROOT}/helm"
K8S_NAMESPACE="shopdeploy"
AWS_REGION=${AWS_REGION:-us-east-1}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[DEPLOY]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

#------------------------------------------------------------------------------
# Get ECR Repository URL
#------------------------------------------------------------------------------
get_ecr_url() {
    local component=$1
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    # Always use prod ECR repos (images are pushed to prod repos regardless of deployment environment)
    echo "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/shopdeploy-prod-${component}"
}

#------------------------------------------------------------------------------
# Deploy Backend
#------------------------------------------------------------------------------
deploy_backend() {
    local ecr_url=$(get_ecr_url "backend")
    
    log_step "Deploying Backend to ${ENVIRONMENT}..."
    
    # Select values file based on environment
    local values_file="${HELM_DIR}/backend/values.yaml"
    if [ -f "${HELM_DIR}/backend/values-${ENVIRONMENT}.yaml" ]; then
        values_file="${HELM_DIR}/backend/values-${ENVIRONMENT}.yaml"
    fi
    
    # Deploy with Helm
    helm upgrade --install shopdeploy-backend "${HELM_DIR}/backend" \
        --namespace ${K8S_NAMESPACE} \
        --create-namespace \
        --values ${values_file} \
        --set image.repository="${ecr_url}" \
        --set image.tag="${TAG}" \
        --set global.environment="${ENVIRONMENT}" \
        --wait \
        --timeout 10m
    
    log_info "Backend deployed: ${ecr_url}:${TAG}"
    
    # Verify deployment
    kubectl rollout status deployment/shopdeploy-backend -n ${K8S_NAMESPACE} --timeout=5m
}

#------------------------------------------------------------------------------
# Deploy Frontend
#------------------------------------------------------------------------------
deploy_frontend() {
    local ecr_url=$(get_ecr_url "frontend")
    
    log_step "Deploying Frontend to ${ENVIRONMENT}..."
    
    # Select values file based on environment
    local values_file="${HELM_DIR}/frontend/values.yaml"
    if [ -f "${HELM_DIR}/frontend/values-${ENVIRONMENT}.yaml" ]; then
        values_file="${HELM_DIR}/frontend/values-${ENVIRONMENT}.yaml"
    fi
    
    # Deploy with Helm
    helm upgrade --install shopdeploy-frontend "${HELM_DIR}/frontend" \
        --namespace ${K8S_NAMESPACE} \
        --create-namespace \
        --values ${values_file} \
        --set image.repository="${ecr_url}" \
        --set image.tag="${TAG}" \
        --set global.environment="${ENVIRONMENT}" \
        --wait \
        --timeout 10m
    
    log_info "Frontend deployed: ${ecr_url}:${TAG}"
    
    # Verify deployment
    kubectl rollout status deployment/shopdeploy-frontend -n ${K8S_NAMESPACE} --timeout=5m
}

#------------------------------------------------------------------------------
# Deploy ConfigMaps and Secrets
#------------------------------------------------------------------------------
deploy_configs() {
    log_step "Applying ConfigMaps and Secrets..."
    
    kubectl apply -f "${PROJECT_ROOT}/k8s/namespace.yaml"
    kubectl apply -f "${PROJECT_ROOT}/k8s/backend-configmap.yaml"
    kubectl apply -f "${PROJECT_ROOT}/k8s/frontend-configmap.yaml"
    
    # Apply secrets only if they exist (should be created separately)
    if [ -f "${PROJECT_ROOT}/k8s/backend-secret.yaml" ]; then
        kubectl apply -f "${PROJECT_ROOT}/k8s/backend-secret.yaml"
    fi
}

#------------------------------------------------------------------------------
# Deploy MongoDB
#------------------------------------------------------------------------------
deploy_mongodb() {
    log_step "Deploying MongoDB..."
    
    # Check if MongoDB is already running
    if kubectl get deployment mongodb -n ${K8S_NAMESPACE} &>/dev/null; then
        log_info "MongoDB is already deployed"
        return 0
    fi
    
    # Deploy MongoDB
    kubectl apply -f "${PROJECT_ROOT}/k8s/mongodb-statefulset.yaml"
    
    # Wait for MongoDB to be ready
    log_info "Waiting for MongoDB to be ready..."
    kubectl rollout status deployment/mongodb -n ${K8S_NAMESPACE} --timeout=3m || log_warn "MongoDB may not be fully ready yet"
}

#------------------------------------------------------------------------------
# Canary Deployment (Progressive Rollout)
#------------------------------------------------------------------------------
canary_deploy() {
    log_warn "Canary deployment enabled - deploying to 10% of traffic first..."
    
    # For canary, we'd typically use:
    # 1. Argo Rollouts
    # 2. Istio traffic splitting
    # 3. AWS App Mesh
    
    # Simple approach: Deploy with fewer replicas first
    helm upgrade --install shopdeploy-backend "${HELM_DIR}/backend" \
        --namespace ${K8S_NAMESPACE} \
        --set replicaCount=1 \
        --set image.tag="${TAG}" \
        --wait
    
    log_info "Canary deployment active. Monitor metrics before full rollout."
    log_info "Run 'helm upgrade --install ... --set replicaCount=3' for full deployment"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
echo "=============================================="
echo "  ShopDeploy Kubernetes Deployment"
echo "  Component: ${COMPONENT}"
echo "  Tag: ${TAG}"
echo "  Environment: ${ENVIRONMENT}"
echo "=============================================="

# Verify cluster connection
log_step "Verifying Kubernetes connection..."
kubectl cluster-info || log_error "Cannot connect to Kubernetes cluster"

# Deploy configs first
deploy_configs

# Deploy MongoDB (required for backend)
deploy_mongodb

# Check for canary deployment
if [ "${CANARY}" == "--canary" ]; then
    canary_deploy
    exit 0
fi

case ${COMPONENT} in
    backend)
        deploy_backend
        ;;
    frontend)
        deploy_frontend
        ;;
    all)
        deploy_backend
        deploy_frontend
        ;;
    *)
        log_error "Unknown component: ${COMPONENT}. Use: backend, frontend, or all"
        ;;
esac

echo ""
log_info "Deployment completed successfully!"

# Show deployment status
echo ""
log_step "Deployment Status:"
kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/part-of=shopdeploy
echo ""
kubectl get svc -n ${K8S_NAMESPACE}
