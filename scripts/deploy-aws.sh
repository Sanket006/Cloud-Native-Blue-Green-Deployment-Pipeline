#!/bin/bash
set -e

echo "=============================================="
echo " Starting AWS Blue-Green Deployment"
echo "=============================================="

# Define AWS Region
REGION="us-east-1"

# 1. Fetch outputs from Terraform
cd terraform
ECR_URL=$(terraform output -raw ecr_repository_url)
CLUSTER_NAME=$(terraform output -raw cluster_name)
cd ..

if [ -z "$ECR_URL" ]; then
    echo "Error: ECR URL not found. Ensure 'terraform apply' has been executed successfully."
    exit 1
fi

echo "[1/5] Authenticating with AWS ECR..."
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR_URL

echo "[2/5] Building and pushing Docker Images to ECR..."
docker build -t $ECR_URL:blue ./app
docker build -t $ECR_URL:green ./app
docker push $ECR_URL:blue
docker push $ECR_URL:green

echo "[3/5] Configuring kubectl for EKS..."
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

echo "[4/5] Deploying Service (Routing to Blue by default)..."
kubectl apply -f k8s/service.yaml

echo "[5/5] Deploying Blue & Green Environments to EKS..."
# Use sed to replace the local image name with the ECR URL and dynamically apply on the fly
sed "s|devops-demo/bg-app|$ECR_URL|g" k8s/blue-deployment.yaml | kubectl apply -f -
sed "s|devops-demo/bg-app|$ECR_URL|g" k8s/green-deployment.yaml | kubectl apply -f -

echo "Waiting for pods to be ready..."
kubectl rollout status deployment/app-blue
kubectl rollout status deployment/app-green

echo "=============================================="
echo " AWS Deployment Complete!"
echo " Get public endpoints with: kubectl get svc bg-demo-service"
echo " (Note: Our service is currently NodePort. You can change k8s/service.yaml type to LoadBalancer if you want an AWS ELB)"
echo " To switch traffic to green, run: ./scripts/switch-traffic.sh green"
echo "=============================================="
