#!/bin/bash
set -e

echo "  Начало процесса деплоя приложения..."

# 1. Создаем секрет для доступа к приватному Yandex Container Registry
# (используем --dry-run=client, чтобы команда была идемпотентной и не падала, если секрет уже есть)
echo "Настройка секрета для доступа к Registry..."
kubectl create secret docker-registry yc-registry-secret \
  --docker-server=cr.yandex \
  --docker-username=json_key \
  --docker-password="$(cat test-app/registry-key.json)" \
  -n default --dry-run=client -o yaml | kubectl apply -f -

# 2. Применяем манифесты из выделенной директории k8s/
echo "Применение Kubernetes манифестов из директории k8s/..."
kubectl apply -f k8s/

echo "Деплой инициирован!"
echo "Проверьте статус подов командой: kubectl get pods -n default"
echo "Проверьте историю деплоев: kubectl rollout history deployment/diploma-test-app"
