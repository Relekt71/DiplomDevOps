#!/bin/bash
set -e

echo "Starting application deployment..."

echo "Configuring secret for Registry access..."
kubectl create secret docker-registry yc-registry-secret \
  --docker-server=cr.yandex \
  --docker-username=json_key \
  --docker-password="$(cat test-app/registry-key.json)" \
  -n default --dry-run=client -o yaml | kubectl apply -f -

echo "Applying Kubernetes manifests from k8s/ directory..."
kubectl apply -f k8s/

echo "Deployment initiated!"
echo "Check pod status: kubectl get pods -n default"
echo "Check rollout history: kubectl rollout history deployment/diploma-test-app"
