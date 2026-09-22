#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="shopsphere"
BASE_DIR="/home/ubuntu/shopsphere-platform/kubernetes/dev"

# ECR Configuration
ECR_REGISTRY="112188881127.dkr.ecr.us-west-2.amazonaws.com"
ECR_REPO="shopsphere"
IMAGE_TAG="v1"

# Services in deployment order (dependencies)
declare -a SERVICES=(
    "redis"               # Public image, not ECR
    "cartservice"
    "productcatalogservice"
    "currencyservice"
    "adservice"
    "recommendationservice"
    "shippingservice"
    "paymentservice"
    "emailservice"
    "checkoutservice"
    "frontend"
)

# Service ports (for verification)
declare -A SERVICE_PORTS
SERVICE_PORTS["redis"]="6379"
SERVICE_PORTS["cartservice"]="7070"
SERVICE_PORTS["productcatalogservice"]="3550"
SERVICE_PORTS["currencyservice"]="7000"
SERVICE_PORTS["adservice"]="9555"
SERVICE_PORTS["recommendationservice"]="8080"
SERVICE_PORTS["shippingservice"]="50051"
SERVICE_PORTS["paymentservice"]="50051"
SERVICE_PORTS["emailservice"]="8080"
SERVICE_PORTS["checkoutservice"]="5050"
SERVICE_PORTS["frontend"]="8080"

# Functions
print_status() { echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_header() { echo ""; echo -e "${GREEN}========================================${NC}"; echo -e "${GREEN}$1${NC}"; echo -e "${GREEN}========================================${NC}"; }

deployment_exists() { kubectl get deployment -n ${NAMESPACE} $1 &> /dev/null; }
service_exists() { kubectl get service -n ${NAMESPACE} $1 &> /dev/null; }
is_pod_ready() {
    local ready=$(kubectl get pods -n ${NAMESPACE} -l app=$1 -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    [ "$ready" == "True" ]
}

verify_service() {
    local service=$1
    print_status "⏳ Waiting for ${service} to be ready..."
    for i in {1..30}; do
        if is_pod_ready "${service}"; then
            print_success "${service} is ready!"
            return 0
        fi
        sleep 2
    done
    print_error "${service} failed to become ready!"
    return 1
}

deploy_service() {
    local service=$1
    local service_dir="${BASE_DIR}/${service}"
    local deploy_file="${service_dir}/deployment.yaml"
    local svc_file="${service_dir}/service.yaml"

    print_header "📦 Processing: ${service}"

    if [ ! -f "${deploy_file}" ]; then
        print_error "Deployment file not found: ${deploy_file}"
        return 1
    fi

    # Determine image to use
    local image_to_use=""
    if [ "${service}" == "redis" ]; then
        # Redis uses public image (keep as is from YAML)
        image_to_use=""
    else
        # ECR image for this service
        image_to_use="${ECR_REGISTRY}/${ECR_REPO}:${service}-${IMAGE_TAG}"
    fi

    # Create a temporary deployment file with correct image
    local temp_deploy="/tmp/${service}-deployment.yaml"
    cp "${deploy_file}" "${temp_deploy}"
    if [ ! -z "${image_to_use}" ]; then
        # Replace image line (assuming the image field exists)
        sed -i "s|image: .*|image: ${image_to_use}|g" "${temp_deploy}"
        print_status "Using image: ${image_to_use}"
    else
        print_status "Using original image (Redis)"
    fi

    # Apply deployment
    kubectl apply -f "${temp_deploy}" -n ${NAMESPACE}
    if [ $? -ne 0 ]; then
        print_error "Failed to apply deployment for ${service}"
        rm -f "${temp_deploy}"
        return 1
    fi

    # Apply service if exists
    if [ -f "${svc_file}" ]; then
        kubectl apply -f "${svc_file}" -n ${NAMESPACE}
    fi

    # Verify
    if verify_service "${service}"; then
        print_success "${service} deployed successfully!"
        rm -f "${temp_deploy}"
        return 0
    else
        print_error "${service} deployment failed verification."
        rm -f "${temp_deploy}"
        return 1
    fi
}

# Function to patch existing deployments (used with --patch)
patch_deployments() {
    print_header "🔄 Patching existing deployments with ECR images"
    for svc in "${SERVICES[@]}"; do
        if [ "${svc}" == "redis" ]; then continue; fi
        if deployment_exists "${svc}"; then
            local new_image="${ECR_REGISTRY}/${ECR_REPO}:${svc}-${IMAGE_TAG}"
            print_status "Patching ${svc} -> ${new_image}"
            kubectl set image deployment/${svc} -n ${NAMESPACE} *=${new_image}
            if [ $? -eq 0 ]; then
                print_success "Patched ${svc}"
            else
                print_error "Failed to patch ${svc}"
            fi
        else
            print_warning "${svc} not deployed, skipping patch"
        fi
    done
}

# Show overall status
show_status() {
    print_header "📊 Current Status"
    kubectl get pods,svc,deployments -n ${NAMESPACE}
}

# Main
main() {
    print_header "🚀 ShopSphere EKS Deployment with ECR Images"
    print_status "Namespace: ${NAMESPACE}"
    print_status "ECR Registry: ${ECR_REGISTRY}/${ECR_REPO}"
    print_status "Image tag: ${IMAGE_TAG}"

    # Check if namespace exists
    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
        print_status "Creating namespace ${NAMESPACE}..."
        kubectl create namespace ${NAMESPACE}
    fi

    # Deploy each service
    local failed=()
    for svc in "${SERVICES[@]}"; do
        if ! deploy_service "${svc}"; then
            failed+=("${svc}")
        fi
    done

    # Summary
    print_header "📋 Deployment Summary"
    if [ ${#failed[@]} -eq 0 ]; then
        print_success "All services deployed successfully!"
    else
        print_error "Failed services: ${failed[*]}"
    fi

    show_status
    print_status "Completed at: $(date)"
}

# Parse arguments
if [[ "$1" == "--patch" ]]; then
    patch_deployments
    show_status
    exit 0
elif [[ "$1" == "--status" ]]; then
    show_status
    exit 0
else
    main
fi
