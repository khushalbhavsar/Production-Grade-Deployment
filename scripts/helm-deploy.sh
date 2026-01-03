#!/bin/bash
#==============================================================================
# ShopDeploy - Helm Deployment Script
# Deploy backend/frontend to Kubernetes using Helm
# Usage: ./helm-deploy.sh <component> <tag> <environment>
#==============================================================================

set -e

COMPONENT=${1:-all}
IMAGE_TAG=${2:-latest}
ENVIRONMENT=${3:-dev}
AWS_REGION=${AWS_REGION:-us-east-1}
DRY_RUN=${DRY_RUN:-false}

PROJECT_ROOT=$(cd "$(dirname "$0")/.." && pwd)

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${CYAN}============================================="
echo "  ShopDeploy - Helm Deployment"
echo "  Component: ${COMPONENT}"
echo "  Environment: ${ENVIRONMENT}"
echo "  Image Tag: ${IMAGE_TAG}"
echo -e "=============================================${NC}"

# Determine namespace
case $ENVIRONMENT in
    prod) NAMESPACE="shopdeploy" ;;
    staging) NAMESPACE="shopdeploy-staging" ;;
    dev) NAMESPACE="shopdeploy-dev" ;;
    *) NAMESPACE="shopdeploy-dev" ;;
esac

# Get AWS Account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [ -z "$AWS_ACCOUNT_ID" ]; then
    log_error "Failed to get AWS Account ID. Ensure AWS CLI is configured."
    exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
log_info "ECR Registry: ${ECR_REGISTRY}"

# Function to deploy a component
deploy_component() {
    local component_name=$1
    local release_name="shopdeploy-${component_name}"
    local chart_path="${PROJECT_ROOT}/helm/${component_name}"
    local values_file="${chart_path}/values.yaml"
    local env_values_file="${chart_path}/values-${ENVIRONMENT}.yaml"
    local image_repo="${ECR_REGISTRY}/shopdeploy-prod-${component_name}"
    
    log_info "Deploying ${component_name}..."
    log_info "Release: ${release_name}"
    log_info "Namespace: ${NAMESPACE}"
    log_info "Image: ${image_repo}:${IMAGE_TAG}"
    
    # Build Helm args
    HELM_ARGS=(
        upgrade --install "${release_name}" "${chart_path}"
        --namespace "${NAMESPACE}"
        --create-namespace
        --set "image.repository=${image_repo}"
        --set "image.tag=${IMAGE_TAG}"
        --values "${values_file}"
        --wait
        --timeout 10m
    )
    
    # Add environment-specific values if exists
    if [ -f "${env_values_file}" ]; then
        HELM_ARGS+=(--values "${env_values_file}")
    fi
    
    # Add dry-run flag if specified
    if [ "$DRY_RUN" = "true" ]; then
        HELM_ARGS+=(--dry-run --debug)
        log_warn "Running in DRY-RUN mode"
    fi
    
    # Execute Helm command
    log_info "Running: helm ${HELM_ARGS[*]}"
    helm "${HELM_ARGS[@]}"
    
    if [ $? -ne 0 ]; then
        log_error "Helm deployment failed for ${component_name}"
        exit 1
    fi
    
    if [ "$DRY_RUN" != "true" ]; then
        log_info "${component_name} deployed successfully!"
        echo ""
        log_info "Deployment Status:"
        kubectl get pods -n "${NAMESPACE}" -l "app.kubernetes.io/name=${component_name}"
    fi
}

# Update kubeconfig for EKS
EKS_CLUSTER_NAME="shopdeploy-${ENVIRONMENT}-eks"
if [ "$ENVIRONMENT" = "prod" ]; then
    EKS_CLUSTER_NAME="shopdeploy-prod-eks"
fi

log_info "Updating kubeconfig for EKS cluster: ${EKS_CLUSTER_NAME}"
aws eks update-kubeconfig --region "${AWS_REGION}" --name "${EKS_CLUSTER_NAME}"

# Deploy components
case $COMPONENT in
    backend)
        deploy_component "backend"
        ;;
    frontend)
        deploy_component "frontend"
        ;;
    all)
        deploy_component "backend"
        deploy_component "frontend"
        ;;
    *)
        log_error "Unknown component: ${COMPONENT}"
        echo "Usage: $0 <backend|frontend|all> <tag> <dev|staging|prod>"
        exit 1
        ;;
esac

echo -e "\n${CYAN}============================================="
echo "  Deployment Complete!"
echo -e "=============================================${NC}"

# Show all resources
if [ "$DRY_RUN" != "true" ]; then
    echo ""
    log_info "All resources in ${NAMESPACE} namespace:"
    kubectl get all -n "${NAMESPACE}"
fi
