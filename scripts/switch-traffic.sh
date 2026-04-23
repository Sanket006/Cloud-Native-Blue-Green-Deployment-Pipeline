#!/bin/bash

# Target environment parameter (blue or green)
TARGET_ENV=$1

if [[ "$TARGET_ENV" != "blue" && "$TARGET_ENV" != "green" ]]; then
    echo "Usage: ./switch-traffic.sh [blue|green]"
    exit 1
fi

echo "Switching traffic to '$TARGET_ENV' environment..."

# Patch the service to select pods with the target version label
# We explicitly set both labels to ensure nothing is dropped
kubectl patch service bg-demo-service -p "{\"spec\":{\"selector\":{\"app\":\"demo-app\",\"version\":\"$TARGET_ENV\"}}}"

echo "Traffic switch requested."
echo "Wait a few seconds and refresh your browser. You should see the $TARGET_ENV environment serving requests."
