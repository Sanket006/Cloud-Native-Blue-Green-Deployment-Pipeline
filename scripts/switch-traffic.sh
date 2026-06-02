#!/bin/bash
set -e

ENV=$1

# 1. Validate argument
if [[ "$ENV" != "blue" && "$ENV" != "green" ]]; then
    echo "Usage: ./switch-traffic.sh [blue|green]"
    exit 1
fi

# 2. Check the cluster is reachable
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo ""
    echo "ERROR: Cannot connect to the Kubernetes cluster."
    echo "Fix  : kind export kubeconfig --name mycluster"
    echo "       kubectl config use-context kind-mycluster"
    exit 1
fi

echo ""
echo ">> Switching traffic to: $ENV"

# 3. Update the Kubernetes service selector to point at the target environment
PATCH='{"spec":{"selector":{"app":"demo-app","version":"'"$ENV"'"}}}'
kubectl patch service bg-demo-service -p "$PATCH" > /dev/null
echo "   [1/2] Service selector updated  ->  version=$ENV"

# 4. Find a running pod for the target environment (used for port-forward)
POD=$(kubectl get pod -l "app=demo-app,version=$ENV" \
    --field-selector=status.phase=Running \
    -o jsonpath='{.items[0].metadata.name}')
echo "   [2/2] Target pod identified     ->  $POD"

echo ""
echo "============================================"
echo "  Traffic is now routed to: $ENV"
echo "============================================"
echo ""
echo "  Next step — run this in a new terminal:"
echo ""
echo "    kubectl port-forward $POD 8080:3000"
echo ""
echo "  Then open: http://localhost:8080"
echo "============================================"
echo ""
