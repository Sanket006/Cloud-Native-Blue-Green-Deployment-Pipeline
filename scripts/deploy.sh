#!/bin/bash
set -e

echo "=============================================="
echo " Starting Blue-Green Deployment Setup"
echo "=============================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    echo "Error: Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if kubectl can reach the cluster before proceeding
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo "Error: Cannot connect to the Kubernetes cluster."
    echo "       Make sure your cluster is running and kubectl context is set correctly."
    echo "       For kind: kind export kubeconfig --name mycluster"
    exit 1
fi

echo "[1/4] Building Docker Images..."
docker build -t devops-demo/bg-app:blue  ./app
docker build -t devops-demo/bg-app:green ./app

# Load images into your local cluster if needed.
# Un-comment ONE of the lines below depending on which tool you use:
# kind (created with kind-config.yaml):
# kind load docker-image devops-demo/bg-app:blue devops-demo/bg-app:green --name mycluster
# minikube:
# minikube image load devops-demo/bg-app:blue devops-demo/bg-app:green

echo "[2/4] Deploying Service (routing to Blue by default)..."
kubectl apply -f k8s/service.yaml

echo "[3/4] Deploying Blue Environment (v1.0)..."
kubectl apply -f k8s/blue-deployment.yaml

echo "[4/4] Deploying Green Environment (v2.0)..."
kubectl apply -f k8s/green-deployment.yaml

echo "Waiting for pods to be ready..."
kubectl rollout status deployment/app-blue
kubectl rollout status deployment/app-green

echo "=============================================="
echo " Deployment Complete!"
echo ""
echo " Access the application:"
echo "   kubectl port-forward service/bg-demo-service 8080:80"
echo "   Then open: http://localhost:8080"
echo ""
echo " To switch traffic to green, run:"
echo "   ./scripts/switch-traffic.sh green"
echo "=============================================="
