#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ECR config
ECR_REGISTRY="112188881127.dkr.ecr.us-west-2.amazonaws.com"
ECR_REPO="shopsphere"
AWS_REGION="us-west-2"
LOCAL_REGISTRY="shopsphere"
IMAGE_TAG="v1"

# All services
SERVICES=(
    "adservice"
    "cartservice"
    "checkoutservice"
    "currencyservice"
    "emailservice"
    "frontend"
    "loadgenerator"
    "paymentservice"
    "productcatalogservice"
    "recommendationservice"
    "shippingservice"
)

echo -e "${GREEN}🚀 Pushing all images to ECR...${NC}"

# 1. Login to ECR
echo "🔐 Logging in to AWS ECR..."
if ! aws ecr get-login-password --region "$AWS_REGION" | docker login --username AWS --password-stdin "$ECR_REGISTRY" > /dev/null 2>&1; then
    echo -e "${RED}❌ Login failed. Check AWS CLI and permissions.${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Logged in.${NC}"

# 2. For each service, tag and push
for svc in "${SERVICES[@]}"; do
    local_image="${LOCAL_REGISTRY}/${svc}:${IMAGE_TAG}"
    ecr_image="${ECR_REGISTRY}/${ECR_REPO}:${svc}-${IMAGE_TAG}"

    echo "📦 Processing $svc ..."

    # Check if local image exists
    if ! docker image inspect "$local_image" &>/dev/null; then
        echo -e "${YELLOW}⚠️  Local image $local_image not found. Skipping.${NC}"
        continue
    fi

    # Tag
    echo "   Tagging $local_image -> $ecr_image"
    docker tag "$local_image" "$ecr_image"

    # Push
    echo "   Pushing $ecr_image ..."
    if docker push "$ecr_image" > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Pushed${NC}"
    else
        echo -e "   ${RED}❌ Push failed${NC}"
    fi
done

echo -e "${GREEN}🎉 Done.${NC}"
