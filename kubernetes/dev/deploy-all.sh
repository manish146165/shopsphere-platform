#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="shopsphere"
BASE_DIR="/home/ubuntu/shopsphere-platform/kubernetes/dev"

# Service deployment order (dependency based)
declare -a SERVICES=(
    "redis"
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

# Service ports for verification
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

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to check if deployment exists
deployment_exists() {
    local service=$1
    kubectl get deployment -n ${NAMESPACE} ${service} &> /dev/null
    return $?
}

# Function to check if service exists
service_exists() {
    local service=$1
    kubectl get service -n ${NAMESPACE} ${service} &> /dev/null
    return $?
}

# Function to check if pod is running
is_pod_running() {
    local service=$1
    local pod_status=$(kubectl get pods -n ${NAMESPACE} -l app=${service} -o jsonpath='{.items[0].status.phase}' 2>/dev/null)
    if [ "$pod_status" == "Running" ]; then
        return 0
    else
        return 1
    fi
}

# Function to check pod readiness
is_pod_ready() {
    local service=$1
    local ready=$(kubectl get pods -n ${NAMESPACE} -l app=${service} -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null)
    if [ "$ready" == "True" ]; then
        return 0
    else
        return 1
    fi
}

# Function to verify service
verify_service() {
    local service=$1
    local max_attempts=30
    local attempt=0
    
    print_status "${BLUE}" "⏳ Waiting for ${service} to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if is_pod_ready "${service}"; then
            print_status "${GREEN}" "✅ ${service} is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    print_status "${RED}" "❌ ${service} failed to become ready!"
    return 1
}

# Function to deploy a service
deploy_service() {
    local service=$1
    local service_dir="${BASE_DIR}/${service}"
    local deploy_file="${service_dir}/deployment.yaml"
    local svc_file="${service_dir}/service.yaml"
    
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "=========================================="
    print_status "${YELLOW}" "📦 Processing: ${service}"
    print_status "${YELLOW}" "=========================================="
    
    # Check if files exist
    if [ ! -f "${deploy_file}" ]; then
        print_status "${RED}" "❌ Deployment file not found: ${deploy_file}"
        return 1
    fi
    
    if [ ! -f "${svc_file}" ]; then
        print_status "${YELLOW}" "⚠️  Service file not found: ${svc_file} (skipping service)"
    fi
    
    # Check if already deployed
    if deployment_exists "${service}" && service_exists "${service}"; then
        print_status "${GREEN}" "✅ ${service} already deployed! Skipping..."
        
        # Still verify it's running
        if is_pod_running "${service}" && is_pod_ready "${service}"; then
            print_status "${GREEN}" "✅ ${service} is running properly!"
            return 0
        else
            print_status "${YELLOW}" "⚠️  ${service} exists but not running properly. Re-deploying..."
        fi
    fi
    
    # Deploy the service
    print_status "${BLUE}" "📥 Deploying ${service}..."
    
    # Apply deployment
    kubectl apply -f "${deploy_file}" -n ${NAMESPACE}
    if [ $? -ne 0 ]; then
        print_status "${RED}" "❌ Failed to deploy ${service}"
        return 1
    fi
    
    # Apply service if exists
    if [ -f "${svc_file}" ]; then
        kubectl apply -f "${svc_file}" -n ${NAMESPACE}
        if [ $? -ne 0 ]; then
            print_status "${YELLOW}" "⚠️  Service file applied with warnings"
        fi
    fi
    
    # Verify the service
    if verify_service "${service}"; then
        # Get pod details
        local pod_name=$(kubectl get pods -n ${NAMESPACE} -l app=${service} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
        if [ ! -z "${pod_name}" ]; then
            print_status "${GREEN}" "📋 Pod: ${pod_name}"
            
            # Check logs (last 5 lines)
            print_status "${BLUE}" "📝 Last 5 log lines:"
            kubectl logs -n ${NAMESPACE} ${pod_name} --tail=5 2>/dev/null || echo "  (No logs yet or log collection disabled)"
        fi
        
        print_status "${GREEN}" "✅ ${service} deployed successfully!"
        return 0
    else
        print_status "${RED}" "❌ ${service} verification failed!"
        return 1
    fi
}

# Function to show overall status
show_overall_status() {
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "=========================================="
    print_status "${YELLOW}" "📊 Overall Deployment Status"
    print_status "${YELLOW}" "=========================================="
    
    echo ""
    print_status "${BLUE}" "Pods in ${NAMESPACE} namespace:"
    kubectl get pods -n ${NAMESPACE}
    
    echo ""
    print_status "${BLUE}" "Services in ${NAMESPACE} namespace:"
    kubectl get svc -n ${NAMESPACE}
    
    echo ""
    print_status "${BLUE}" "Deployments in ${NAMESPACE} namespace:"
    kubectl get deployments -n ${NAMESPACE}
    
    echo ""
    print_status "${BLUE}" "ConfigMaps in ${NAMESPACE} namespace:"
    kubectl get configmaps -n ${NAMESPACE}
}

# Function to deep verify all services
deep_verify() {
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "=========================================="
    print_status "${YELLOW}" "🔍 Deep Verification Report"
    print_status "${YELLOW}" "=========================================="
    
    local all_ok=true
    
    for service in "${SERVICES[@]}"; do
        echo ""
        print_status "${BLUE}" "Checking ${service}:"
        
        if deployment_exists "${service}"; then
            if is_pod_running "${service}" && is_pod_ready "${service}"; then
                print_status "${GREEN}" "  ✅ Running and Ready"
                
                # Get pod name and IP
                local pod_name=$(kubectl get pods -n ${NAMESPACE} -l app=${service} -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
                local pod_ip=$(kubectl get pods -n ${NAMESPACE} -l app=${service} -o jsonpath='{.items[0].status.podIP}' 2>/dev/null)
                echo "  📍 Pod: ${pod_name}"
                echo "  🔌 IP: ${pod_ip}"
                
                # Check if service exists
                if service_exists "${service}"; then
                    local svc_ip=$(kubectl get svc -n ${NAMESPACE} ${service} -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
                    echo "  🌐 Service IP: ${svc_ip}"
                fi
            else
                print_status "${RED}" "  ❌ Not running or not ready"
                all_ok=false
            fi
        else
            print_status "${RED}" "  ❌ Not deployed"
            all_ok=false
        fi
    done
    
    echo ""
    if [ "$all_ok" = true ]; then
        print_status "${GREEN}" "✅ All services are running properly!"
    else
        print_status "${RED}" "❌ Some services have issues. Please check above."
    fi
}

# Function to check service connectivity
check_connectivity() {
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "=========================================="
    print_status "${YELLOW}" "🌐 Service Connectivity Check"
    print_status "${YELLOW}" "=========================================="
    
    # Test curl to frontend if it's a LoadBalancer
    local frontend_type=$(kubectl get svc -n ${NAMESPACE} frontend -o jsonpath='{.spec.type}' 2>/dev/null)
    if [ "$frontend_type" == "LoadBalancer" ]; then
        local frontend_ip=$(kubectl get svc -n ${NAMESPACE} frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
        local frontend_port=$(kubectl get svc -n ${NAMESPACE} frontend -o jsonpath='{.spec.ports[0].port}' 2>/dev/null)
        if [ ! -z "${frontend_ip}" ]; then
            print_status "${GREEN}" "✅ Frontend accessible at: http://${frontend_ip}:${frontend_port}"
        else
            print_status "${YELLOW}" "⚠️  Frontend LoadBalancer IP pending..."
        fi
    fi
}

# Main execution
main() {
    print_status "${GREEN}" "=========================================="
    print_status "${GREEN}" "🚀 ShopSphere EKS Deployment Script"
    print_status "${GREEN}" "=========================================="
    print_status "${BLUE}" "Starting deployment at: $(date)"
    print_status "${BLUE}" "Namespace: ${NAMESPACE}"
    print_status "${BLUE}" "Services to deploy: ${#SERVICES[@]}"
    
    # Verify namespace exists
    if ! kubectl get namespace ${NAMESPACE} &> /dev/null; then
        print_status "${YELLOW}" "⚠️  Namespace ${NAMESPACE} not found. Creating..."
        kubectl create namespace ${NAMESPACE}
    fi
    
    # Deploy each service in order
    local failed_services=()
    
    for service in "${SERVICES[@]}"; do
        if ! deploy_service "${service}"; then
            failed_services+=("${service}")
        fi
    done
    
    # Show overall status
    show_overall_status
    
    # Deep verify all services
    deep_verify
    
    # Check connectivity
    check_connectivity
    
    # Summary
    print_status "${YELLOW}" ""
    print_status "${YELLOW}" "=========================================="
    print_status "${YELLOW}" "📋 Deployment Summary"
    print_status "${YELLOW}" "=========================================="
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_status "${GREEN}" "✅ All services deployed successfully!"
        print_status "${GREEN}" "🎉 ShopSphere is fully operational!"
    else
        print_status "${RED}" "❌ Failed services: ${failed_services[*]}"
        print_status "${YELLOW}" "💡 Check logs above for details"
    fi
    
    print_status "${BLUE}" "Completed at: $(date)"
}

# Run the main function
main
