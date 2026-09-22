#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
REGISTRY="shopsphere"
IMAGE_TAG="v1"
BASE_DIR="/home/ubuntu/shopsphere-platform/application"

# Services and their build contexts
declare -A SERVICES
SERVICES=(
    ["adservice"]="adservice"
    ["cartservice"]="cartservice/src"
    ["checkoutservice"]="checkoutservice"
    ["currencyservice"]="currencyservice"
    ["emailservice"]="emailservice"
    ["frontend"]="frontend"
    ["loadgenerator"]="loadgenerator"
    ["paymentservice"]="paymentservice"
    ["productcatalogservice"]="productcatalogservice"
    ["recommendationservice"]="recommendationservice"
    ["shippingservice"]="shippingservice"
)

# Function to print colored output
print_status() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_header() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}$1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# Function to build a single service
build_service() {
    local service_name=$1
    local service_dir=$2
    local full_path="${BASE_DIR}/${service_dir}"
    local image_name="${REGISTRY}/${service_name}:${IMAGE_TAG}"
    
    print_header "Building: ${service_name}"
    
    # Check if directory exists
    if [ ! -d "${full_path}" ]; then
        print_error "Directory not found: ${full_path}"
        return 1
    fi
    
    # Check if Dockerfile exists
    if [ ! -f "${full_path}/Dockerfile" ]; then
        print_warning "Dockerfile not found in ${full_path}, skipping..."
        return 0
    fi
    
    # Check if image already exists
    if docker image inspect "${image_name}" &>/dev/null; then
        print_warning "Image ${image_name} already exists"
        read -p "Do you want to rebuild? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_status "Skipping ${service_name}"
            return 0
        fi
    fi
    
    # Build the image
    print_status "Building ${image_name} from ${full_path}..."
    
    cd "${full_path}"
    
    # Special handling for cartservice (Dockerfile is in src directory)
    if [ "${service_name}" == "cartservice" ]; then
        docker build -t "${image_name}" -f Dockerfile .
    else
        docker build -t "${image_name}" .
    fi
    
    if [ $? -eq 0 ]; then
        print_success "Successfully built ${image_name}"
        
        # Show image details
        local image_size=$(docker image inspect "${image_name}" --format='{{.Size}}' | numfmt --to=iec)
        print_status "Image size: ${image_size}"
        
        return 0
    else
        print_error "Failed to build ${image_name}"
        return 1
    fi
}

# Function to list all built images
list_images() {
    print_header "Built Images Summary"
    echo ""
    printf "%-30s %-20s %-15s\n" "IMAGE" "TAG" "SIZE"
    echo "----------------------------------------------------------------"
    
    for service in "${!SERVICES[@]}"; do
        local image_name="${REGISTRY}/${service}:${IMAGE_TAG}"
        if docker image inspect "${image_name}" &>/dev/null; then
            local size=$(docker image inspect "${image_name}" --format='{{.Size}}' | numfmt --to=iec)
            printf "%-30s %-20s %-15s\n" "${image_name}" "${IMAGE_TAG}" "${size}"
        fi
    done
}

# Function to clean old images
clean_images() {
    print_header "Cleaning Old Images"
    
    for service in "${!SERVICES[@]}"; do
        local image_name="${REGISTRY}/${service}:${IMAGE_TAG}"
        if docker image inspect "${image_name}" &>/dev/null; then
            read -p "Remove ${image_name}? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                docker rmi "${image_name}"
                print_success "Removed ${image_name}"
            fi
        fi
    done
}

# Main execution
main() {
    print_header "🚀 ShopSphere Docker Images Build Script"
    print_status "Starting at: $(date)"
    print_status "Base directory: ${BASE_DIR}"
    print_status "Registry: ${REGISTRY}"
    print_status "Tag: ${IMAGE_TAG}"
    echo ""
    
    # Check if Docker is running
    if ! docker info &>/dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Display services to be built
    print_status "Services to build:"
    for service in "${!SERVICES[@]}"; do
        echo "  - ${service} (${SERVICES[$service]})"
    done
    echo ""
    
    read -p "Continue with build? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_status "Build cancelled."
        exit 0
    fi
    
    # Build each service
    local failed_services=()
    local successful_services=()
    
    for service in "${!SERVICES[@]}"; do
        if build_service "${service}" "${SERVICES[$service]}"; then
            successful_services+=("${service}")
        else
            failed_services+=("${service}")
        fi
    done
    
    # Summary
    print_header "Build Summary"
    echo ""
    print_status "Total services: ${#SERVICES[@]}"
    print_success "Successful: ${#successful_services[@]}"
    
    if [ ${#successful_services[@]} -gt 0 ]; then
        echo ""
        print_success "Successfully built:"
        for service in "${successful_services[@]}"; do
            echo "  ✅ ${service}"
        done
    fi
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        print_error "Failed: ${#failed_services[@]}"
        echo ""
        print_error "Failed services:"
        for service in "${failed_services[@]}"; do
            echo "  ❌ ${service}"
        done
    fi
    
    # List all images
    list_images
    
    # Save image list to file
    echo ""
    print_status "Saving image list to ~/built-images.txt..."
    docker images | grep "${REGISTRY}" > ~/built-images.txt
    print_success "Image list saved to ~/built-images.txt"
    
    print_header "🎉 Build Process Complete"
    print_status "Completed at: $(date)"
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All images built successfully!"
    else
        print_warning "Some images failed to build. Check logs above."
    fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            clean_images
            exit 0
            ;;
        --list)
            list_images
            exit 0
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --clean    Remove all built images"
            echo "  --list     List all built images"
            echo "  --help     Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
    shift
done

# Run main function
main
