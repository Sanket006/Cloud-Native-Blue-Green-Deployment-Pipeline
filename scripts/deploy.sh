#!/bin/bash
set -e

echo "=============================================="
echo " Starting Blue-Green Deployment Setup"
echo "=============================================="

# Check if docker is running
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker is not running."
  exit 1
fi

echo "[1/4] Building Docker Images..."
docker build -t devops-demo/bg-app:blue ./app
docker build -t devops-demo/bg-app:green ./app

# Optional: If you are using minikube or kind, you might need to load the image.
# Un-comment the line below for kind:
# kind load docker-image devops-demo/bg-app:blue devops-demo/bg-app:green
# Un-comment the line below for minikube:
# minikube image load devops-demo/bg-app:blue devops-demo/bg-app:green

echo "[2/4] Deploying Service (Routing to Blue by default)..."
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
echo " Access the application using 'kubectl port-forward service/bg-demo-service 8080:80'"
echo " Then navigate to http://localhost:8080 or port 30080 if using a local cluster (NodePort)."
echo " To switch traffic to green, run: ./scripts/switch-traffic.sh green"
echo "=============================================="
