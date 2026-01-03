#!/bin/bash
#==============================================================================
# ShopDeploy - Push Script
# Pushes Docker images to AWS ECR
# Usage: ./push.sh <component> <tag> <ecr_repo_url>
#==============================================================================

set -e

COMPONENT=${1:-all}
TAG=${2:-latest}
ECR_REPO=${3:-""}
AWS_REGION=${AWS_REGION:-us-east-1}

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[PUSH]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#------------------------------------------------------------------------------
# Validate ECR Login
#------------------------------------------------------------------------------
ecr_login() {
    log_info "Logging into AWS ECR..."
    
    # Get AWS account ID if not provided
    if [ -z "${ECR_REPO}" ]; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
    else
        ECR_REGISTRY=$(echo ${ECR_REPO} | cut -d'/' -f1)
    fi
    
    # Login to ECR
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${ECR_REGISTRY}
    
    log_info "Successfully logged into ECR: ${ECR_REGISTRY}"
}

#------------------------------------------------------------------------------
# Push Backend Image
#------------------------------------------------------------------------------
push_backend() {
    local repo_url=${ECR_REPO:-"${ECR_REGISTRY}/shopdeploy-prod-backend"}
    
    log_info "Pushing Backend image to ECR..."
    
    # Tag for ECR
    docker tag "shopdeploy-backend:${TAG}" "${repo_url}:${TAG}"
    docker tag "shopdeploy-backend:${TAG}" "${repo_url}:latest"
    
    # Push to ECR
    docker push "${repo_url}:${TAG}"
    docker push "${repo_url}:latest"
    
    log_info "Backend pushed: ${repo_url}:${TAG}"
}

#------------------------------------------------------------------------------
# Push Frontend Image
#------------------------------------------------------------------------------
push_frontend() {
    local repo_url=${ECR_REPO:-"${ECR_REGISTRY}/shopdeploy-prod-frontend"}
    
    log_info "Pushing Frontend image to ECR..."
    
    # Tag for ECR
    docker tag "shopdeploy-frontend:${TAG}" "${repo_url}:${TAG}"
    docker tag "shopdeploy-frontend:${TAG}" "${repo_url}:latest"
    
    # Push to ECR
    docker push "${repo_url}:${TAG}"
    docker push "${repo_url}:latest"
    
    log_info "Frontend pushed: ${repo_url}:${TAG}"
}

#------------------------------------------------------------------------------
# Main Execution
#------------------------------------------------------------------------------
echo "=============================================="
echo "  ShopDeploy Image Push to ECR"
echo "  Component: ${COMPONENT}"
echo "  Tag: ${TAG}"
echo "=============================================="

# Login to ECR
ecr_login

case ${COMPONENT} in
    backend)
        push_backend
        ;;
    frontend)
        push_frontend
        ;;
    all)
        push_backend
        push_frontend
        ;;
    *)
        log_error "Unknown component: ${COMPONENT}. Use: backend, frontend, or all"
        ;;
esac

echo ""
log_info "Push completed successfully!"
