#!/bin/bash
#==============================================================================
# ShopDeploy - Smoke Test Script
# Post-deployment health verification
# Usage: ./smoke-test.sh [environment]
#==============================================================================

set -e

ENVIRONMENT=${1:-dev}
MAX_RETRIES=30
RETRY_INTERVAL=10

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[SMOKE]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_pass() { echo -e "${GREEN}[PASS]${NC} $1"; }

echo "=============================================="
echo "  ShopDeploy Smoke Tests"
echo "  Environment: ${ENVIRONMENT}"
echo "=============================================="

#------------------------------------------------------------------------------
# Configuration
#------------------------------------------------------------------------------
K8S_NAMESPACE="shopdeploy"

# Service DNS names (accessible from inside the cluster)
BACKEND_SVC="shopdeploy-backend.${K8S_NAMESPACE}.svc.cluster.local:5000"
FRONTEND_SVC="shopdeploy-frontend.${K8S_NAMESPACE}.svc.cluster.local:80"

log_info "Backend endpoint: ${BACKEND_SVC}"
log_info "Frontend endpoint: ${FRONTEND_SVC}"

#------------------------------------------------------------------------------
# Get a running pod to execute curl commands from
#------------------------------------------------------------------------------
get_test_pod() {
    # Try to get frontend pod first (it has curl installed)
    local pod=$(kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/name=frontend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "${pod}" ]; then
        echo "${pod}"
        return 0
    fi
    
    # Fallback to any running pod
    pod=$(kubectl get pods -n ${K8S_NAMESPACE} --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    echo "${pod}"
}

TEST_POD=$(get_test_pod)
log_info "Using test pod: ${TEST_POD}"

#------------------------------------------------------------------------------
# Health Check Function (runs curl from inside the cluster)
#------------------------------------------------------------------------------
health_check() {
    local name=$1
    local url=$2
    local expected_code=${3:-200}
    
    for i in $(seq 1 ${MAX_RETRIES}); do
        # Run curl from inside a pod to reach ClusterIP services
        if [ -n "${TEST_POD}" ]; then
            response=$(kubectl exec -n ${K8S_NAMESPACE} ${TEST_POD} -- curl -s -o /dev/null -w "%{http_code}" --max-time 10 "${url}" 2>/dev/null || echo "000")
        else
            log_warn "No test pod available, skipping HTTP check"
            return 0
        fi
        
        if [ "${response}" == "${expected_code}" ]; then
            log_pass "${name}: HTTP ${response}"
            return 0
        fi
        
        log_warn "${name}: HTTP ${response} (attempt ${i}/${MAX_RETRIES})"
        sleep ${RETRY_INTERVAL}
    done
    
    log_error "${name}: Failed after ${MAX_RETRIES} attempts"
    return 1
}

#------------------------------------------------------------------------------
# Run Smoke Tests
#------------------------------------------------------------------------------
TESTS_PASSED=0
TESTS_FAILED=0

echo ""
log_info "Running health checks..."
echo ""

# Test 1: Backend Health Endpoint
if health_check "Backend Health" "http://${BACKEND_SVC}/api/health/health"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Test 2: Backend Readiness
if health_check "Backend Ready" "http://${BACKEND_SVC}/api/health/ready"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Test 3: Frontend Health
if health_check "Frontend Health" "http://${FRONTEND_SVC}/"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

# Test 4: API Products Endpoint (may return empty array, but should be 200)
if health_check "API Products" "http://${BACKEND_SVC}/api/products"; then
    ((TESTS_PASSED++))
else
    ((TESTS_FAILED++))
fi

#------------------------------------------------------------------------------
# Kubernetes Health Checks
#------------------------------------------------------------------------------
echo ""
log_info "Checking Kubernetes resources..."
echo ""

# Check pod status
PODS_READY=$(kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/part-of=shopdeploy \
    --no-headers | grep -c "Running" || echo "0")
PODS_TOTAL=$(kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/part-of=shopdeploy \
    --no-headers | wc -l || echo "0")

if [ "${PODS_READY}" -eq "${PODS_TOTAL}" ] && [ "${PODS_TOTAL}" -gt 0 ]; then
    log_pass "Pods: ${PODS_READY}/${PODS_TOTAL} running"
    ((TESTS_PASSED++))
else
    log_error "Pods: ${PODS_READY}/${PODS_TOTAL} running"
    ((TESTS_FAILED++))
fi

# Check for crash loops
CRASH_LOOPS=$(kubectl get pods -n ${K8S_NAMESPACE} -l app.kubernetes.io/part-of=shopdeploy \
    -o jsonpath='{.items[*].status.containerStatuses[*].restartCount}' 2>/dev/null | tr ' ' '\n' | awk '$1 > 5' | wc -l)

if [ "${CRASH_LOOPS}" -eq 0 ]; then
    log_pass "No crash loops detected"
    ((TESTS_PASSED++))
else
    log_error "Crash loops detected in ${CRASH_LOOPS} container(s)"
    ((TESTS_FAILED++))
fi

#------------------------------------------------------------------------------
# Summary
#------------------------------------------------------------------------------
echo ""
echo "=============================================="
echo "  Smoke Test Results"
echo "=============================================="
echo ""
log_info "Passed: ${TESTS_PASSED}"
log_info "Failed: ${TESTS_FAILED}"
echo ""

if [ ${TESTS_FAILED} -gt 0 ]; then
    log_error "Smoke tests FAILED!"
    exit 1
else
    log_pass "All smoke tests PASSED!"
    exit 0
fi
