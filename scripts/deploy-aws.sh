#!/bin/bash
set -e

echo "=============================================="
echo " Starting AWS Blue-Green Deployment"
echo "=============================================="

# Define AWS region
REGION="us-east-1"

# 1. Fetch outputs from Terraform
cd terraform || { echo "Error: 'terraform/' directory not found. Run this script from the project root."; exit 1; }
# Suppress stderr to keep warning outputs clean
ECR_URL=$(terraform output -raw ecr_repository_url 2>/dev/null || true)
CLUSTER_NAME=$(terraform output -raw cluster_name 2>/dev/null || true)
cd ..

# Validate that both required Terraform outputs were successfully retrieved and are not warnings
if [ -z "$ECR_URL" ] || [[ "$ECR_URL" == *"Warning:"* ]] || [[ ! "$ECR_URL" =~ amazonaws\.com ]]; then
    echo "========================================================================="
    echo "❌ Error: AWS ECR Registry URL was not found or is invalid!"
    echo "   Actual ECR output: $ECR_URL"
    echo "   Please ensure that your infrastructure has been provisioned successfully"
    echo "   using Terraform ('terraform apply') before running deployments."
    echo "========================================================================="
    exit 1
fi

if [ -z "$CLUSTER_NAME" ] || [[ "$CLUSTER_NAME" == *"Warning:"* ]]; then
    echo "========================================================================="
    echo "❌ Error: AWS EKS Cluster Name was not found or is invalid!"
    echo "   Actual Cluster output: $CLUSTER_NAME"
    echo "   Please ensure that your infrastructure has been provisioned successfully"
    echo "   using Terraform ('terraform apply') before running deployments."
    echo "========================================================================="
    exit 1
fi

echo "[1/5] Authenticating with AWS ECR..."
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$ECR_URL"

echo "[2/5] Building and pushing Docker images to ECR..."
docker build -t "$ECR_URL:blue"  ./app
docker build -t "$ECR_URL:green" ./app
docker push "$ECR_URL:blue"
docker push "$ECR_URL:green"

echo "[3/5] Configuring kubectl for EKS..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER_NAME"

echo "[4/5] Deploying Service (routing to Blue by default)..."
kubectl apply -f k8s/service.yaml

echo "[5/5] Deploying Blue & Green Environments to EKS..."
# Replace the local image name with the ECR URL at apply time (no file is modified on disk)
sed "s|devops-demo/bg-app|$ECR_URL|g" k8s/blue-deployment.yaml  | kubectl apply -f -
sed "s|devops-demo/bg-app|$ECR_URL|g" k8s/green-deployment.yaml | kubectl apply -f -

echo "Waiting for pods to be ready..."
kubectl rollout status deployment/app-blue
kubectl rollout status deployment/app-green

echo "=============================================="
echo " AWS Deployment Complete!"
echo ""
echo " Get the public endpoint:"
echo "   kubectl get svc bg-demo-service"
echo ""
echo " Note: service.yaml uses NodePort by default."
echo " Change 'type: NodePort' to 'type: LoadBalancer' in k8s/service.yaml"
echo " to get an AWS ELB address automatically."
echo ""
echo " To switch traffic to green, run:"
echo "   ./scripts/switch-traffic.sh green"
echo "=============================================="
