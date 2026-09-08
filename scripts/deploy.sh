#!/bin/bash
set -euo pipefail

# ============================================
# DIPLOM DEVOPS - ПОЛНЫЙ DEPLOY SCRIPT
# ============================================

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Логирование
log() {
    echo -e "${BLUE}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
    exit 1
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    
    local deps=("terraform" "ansible" "kubectl" "helm" "docker" "yc" "git" "jq")
    
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            error "Зависимость $dep не найдена. Установите её перед запуском."
        fi
    done
    
    success "Все зависимости установлены"
}

# Проверка переменных окружения
check_env() {
    log "Проверка переменных окружения..."
    
    if [ -z "${YC_TOKEN:-}" ] && [ ! -f "/home/relekt/tokens/token.json" ]; then
        error "YC_TOKEN не установлен и файл токена не найден"
    fi
    
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        warn "GITHUB_TOKEN не установлен. Некоторые шаги GitHub могут не работать."
    fi
    
    success "Переменные окружения проверены"
}

# Шаг 1: Развертывание инфраструктуры
deploy_infrastructure() {
    log "=== ШАГ 1: Развертывание инфраструктуры ==="
    
    cd ~/Netology/DiplomDevOps/infra-main
    
    log "Инициализация Terraform..."
    terraform init
    
    log "Планирование изменений..."
    terraform plan -out=tfplan
    
    log "Применение изменений..."
    terraform apply tfplan
    
    # Сохраняем IP мастера
    MASTER_IP=$(terraform output -raw master_public_ip)
    echo "$MASTER_IP" > ~/Netology/DiplomDevOps/master_ip.txt
    
    success "Инфраструктура развернута. Master IP: $MASTER_IP"
}

# Шаг 2: Создание Container Registry
deploy_registry() {
    log "=== ШАГ 2: Создание Container Registry ==="
    
    cd ~/Netology/DiplomDevOps/infra-registry
    
    log "Инициализация Terraform..."
    terraform init
    
    log "Применение изменений..."
    terraform apply -auto-approve
    
    # Сохраняем ID реестра и SA
    REGISTRY_ID=$(terraform output -raw registry_id)
    SA_ID=$(terraform output -raw registry_sa_id)
    
    echo "$REGISTRY_ID" > ~/Netology/DiplomDevOps/registry_id.txt
    echo "$SA_ID" > ~/Netology/DiplomDevOps/registry_sa_id.txt
    
    success "Registry создан. ID: $REGISTRY_ID"
}

# Шаг 3: Подготовка SSH ключей
setup_ssh_keys() {
    log "=== ШАГ 3: Подготовка SSH ключей ==="
    
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        error "SSH ключ не найден: $SSH_KEY_PATH"
    fi
    
    chmod 600 "$SSH_KEY_PATH"
    
    # Копируем ключ на мастер для Ansible
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_KEY_PATH" ubuntu@$MASTER_IP:~/ssh_key
    
    success "SSH ключи подготовлены"
}

# Шаг 4: Установка Kubernetes через Kubespray
install_kubernetes() {
    log "=== ШАГ 4: Установка Kubernetes через Kubespray ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    # Подключаемся к мастеру и выполняем установку
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'KUBESPRAY_EOF'
set -euo pipefail

# Обновляем пакеты
sudo DEBIAN_FRONTEND=noninteractive apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y python3-pip python3-venv git

# Клонируем Kubespray
cd ~
if [ ! -d "kubespray" ]; then
    git clone https://github.com/kubernetes-sigs/kubespray.git
fi
cd kubespray
git checkout v2.26.0

# Создаем виртуальное окружение
python3 -m venv venv
source venv/bin/activate

# Устанавливаем зависимости
pip3 install --upgrade pip
pip3 install -r requirements.txt
pip3 install ruamel.yaml

# Генерируем инвентарь
cp -rfp inventory/sample inventory/mycluster

# Получаем приватные IP воркеров
WORKER1_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
# Для простоты используем захардкоженные IP (в реальном проекте нужно получать динамически)
declare -a IPS=(10.10.0.8 10.10.0.29 10.11.0.3)
CONFIG_FILE=inventory/mycluster/hosts.yml python3 contrib/inventory_builder/inventory.py ${IPS[@]}

# Исправляем инвентарь (1 мастер, 2 воркера)
cat > inventory/mycluster/hosts.yml << 'INVENTORY_EOF'
all:
  hosts:
    node1:
      ansible_host: 10.10.0.8
      ip: 10.10.0.8
      access_ip: 10.10.0.8
    node2:
      ansible_host: 10.10.0.29
      ip: 10.10.0.29
      access_ip: 10.10.0.29
    node3:
      ansible_host: 10.11.0.3
      ip: 10.11.0.3
      access_ip: 10.11.0.3
  children:
    kube_control_plane:
      hosts:
        node1:
    kube_node:
      hosts:
        node1:
        node2:
        node3:
    etcd:
      hosts:
        node1:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
    calico_rr:
      hosts: {}
INVENTORY_EOF

# Настраиваем переменные
cat > inventory/mycluster/group_vars/all/all.yml << 'VARS_EOF'
---
kubelet_cgroup_driver: systemd
container_manager: containerd
kubelet_fail_swap_on: true
ignore_assert_errors: true
VARS_EOF

# Запускаем установку
ansible-playbook -i inventory/mycluster/hosts.yml \
  -b \
  -v \
  --private-key=~/ssh_key \
  --user=ubuntu \
  cluster.yml || {
    echo "Первый запуск не удался, пробуем повторно..."
    ansible-playbook -i inventory/mycluster/hosts.yml \
      -b \
      -v \
      --private-key=~/ssh_key \
      --user=ubuntu \
      cluster.yml
  }

# Настраиваем kubectl
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

echo "Kubernetes установлен успешно!"
KUBESPRAY_EOF
    
    success "Kubernetes установлен"
}

# Шаг 5: Пост-настройка кластера
post_setup_cluster() {
    log "=== ШАГ 5: Пост-настройка кластера ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'POSTSETUP_EOF'
set -euo pipefail

# Устанавливаем Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Добавляем репозитории
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Устанавливаем Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer || true

# Ждем получения IP (если не получится, используем NodePort)
sleep 30

# Создаем манифест приложения
cat > ~/test-app.yaml << 'APP_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diploma-test-app
  labels:
    app: diploma-test-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: diploma-test-app
  template:
    metadata:
      labels:
        app: diploma-test-app
    spec:
      imagePullSecrets:
        - name: yc-registry-secret
      containers:
      - name: test-app
        image: cr.yandex/crpht3918eo252ctvgjn/diploma-test-app:v1.0.0
        ports:
        - containerPort: 80
        imagePullPolicy: Always
---
apiVersion: v1
kind: Service
metadata:
  name: diploma-test-app-svc
spec:
  type: NodePort
  selector:
    app: diploma-test-app
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
      nodePort: 32042
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: diploma-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  rules:
  - http:
      paths:
      - path: /app(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: diploma-test-app-svc
            port:
              number: 80
APP_EOF

kubectl apply -f ~/test-app.yaml

# Устанавливаем мониторинг
cat > ~/monitoring-values.yaml << 'MONITORING_EOF'
grafana:
  adminPassword: "diploma-admin"
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - ""
    paths:
      - /grafana
    pathType: Prefix
  grafana.ini:
    server:
      root_url: "http://%(domain)s:%(http_port)s/grafana/"
      serve_from_sub_path: true

prometheus:
  prometheusSpec:
    retention: 1d

alertmanager:
  enabled: true

kube-state-metrics:
  enabled: true

prometheus-node-exporter:
  enabled: true
MONITORING_EOF

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f ~/monitoring-values.yaml

echo "Пост-настройка завершена!"
POSTSETUP_EOF
    
    success "Кластер настроен"
}

# Шаг 6: Настройка локального kubeconfig
setup_local_kubeconfig() {
    log "=== ШАГ 6: Настройка локального kubeconfig ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    # Копируем kubeconfig с мастера
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP:~/.kube/config ~/.kube/config
    
    # Модифицируем для внешнего доступа
    sed -i 's|server: https://.*:6443|server: https://'"$MASTER_IP"':6443|g' ~/.kube/config
    sed -i '/certificate-authority-data:/d' ~/.kube/config
    sed -i '/server: https:\/\/'"$MASTER_IP"':6443/a\    insecure-skip-tls-verify: true' ~/.kube/config
    
    chmod 600 ~/.kube/config
    
    success "Локальный kubeconfig настроен"
}

# Шаг 7: Создание SA ключа и настройка Docker
setup_registry_access() {
    log "=== ШАГ 7: Настройка доступа к Registry ==="
    
    SA_ID=$(cat ~/Netology/DiplomDevOps/registry_sa_id.txt)
    
    # Создаем ключ SA
    yc iam key create --service-account-id $SA_ID --output ~/Netology/DiplomDevOps/registry-key.json
    
    # Добавляем права pusher
    REGISTRY_ID=$(cat ~/Netology/DiplomDevOps/registry_id.txt)
    yc container registry add-access-binding $REGISTRY_ID \
      --role container-registry.images.admin \
      --service-account-id $SA_ID
    
    # Настраиваем Docker
    yc container registry configure-docker
    
    success "Доступ к Registry настроен"
}

# Шаг 8: Сборка и пуш Docker-образа
build_and_push_image() {
    log "=== ШАГ 8: Сборка и пуш Docker-образа ==="
    
    cd ~/Netology/DiplomDevOps/test-app
    
    REGISTRY_ID=$(cat ~/Netology/DiplomDevOps/registry_id.txt)
    
    # Собираем образ
    docker build -t diploma-test-app:v1.0.0 .
    
    # Тегируем и пушим
    docker tag diploma-test-app:v1.0.0 cr.yandex/$REGISTRY_ID/diploma-test-app:v1.0.0
    docker push cr.yandex/$REGISTRY_ID/diploma-test-app:v1.0.0
    
    success "Образ собран и отправлен в Registry"
}

# Шаг 9: Создание GitHub репозитория и настройка CI/CD
setup_github_cicd() {
    log "=== ШАГ 9: Настройка GitHub CI/CD ==="
    
    if [ -z "${GITHUB_TOKEN:-}" ]; then
        warn "GITHUB_TOKEN не установлен. Пропускаем настройку GitHub."
        return 0
    fi
    
    cd ~/Netology/DiplomDevOps/test-app
    
    # Инициализируем Git
    git init
    git remote add origin https://github.com/Relekt71/DiplomDevOps.git || git remote set-url origin https://github.com/Relekt71/DiplomDevOps.git
    git branch -M main
    
    # Создаем workflow
    mkdir -p .github/workflows
    cat > .github/workflows/ci-cd.yml << 'WORKFLOW_EOF'
name: Build and Deploy to Kubernetes

on:
  push:
    branches:
      - main
    tags:
      - 'v*'

env:
  REGISTRY: cr.yandex/crpht3918eo252ctvgjn
  IMAGE_NAME: diploma-test-app

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Yandex Container Registry
        uses: docker/login-action@v3
        with:
          registry: cr.yandex
          username: json_key
          password: ${{ secrets.YC_SA_KEY }}

      - name: Extract metadata for Docker
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=tag

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          platforms: linux/amd64
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          provenance: false
          sbom: false

  deploy:
    needs: build-and-push
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set Kubernetes context
        uses: azure/k8s-set-context@v4
        with:
          method: kubeconfig
          kubeconfig: ${{ secrets.KUBE_CONFIG }}

      - name: Deploy to Kubernetes
        run: |
          TAG=${GITHUB_REF#refs/tags/}
          echo "Deploying version: $TAG"
          kubectl cluster-info
          kubectl set image deployment/diploma-test-app test-app=${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:${TAG} -n default
          kubectl rollout status deployment/diploma-test-app -n default
WORKFLOW_EOF
    
    # Коммитим и пушим
    git add .
    git commit -m "Initial commit: automated deployment"
    git push -u origin main
    
    # Создаем секреты через gh CLI (если установлен)
    if command -v gh &> /dev/null; then
        log "Создание GitHub secrets..."
        
        # KUBE_CONFIG
        gh secret set KUBE_CONFIG < ~/.kube/config
        
        # YC_SA_KEY
        gh secret set YC_SA_KEY < ~/Netology/DiplomDevOps/registry-key.json
        
        success "GitHub secrets созданы"
    else
        warn "gh CLI не установлен. Создайте секреты вручную в GitHub."
    fi
    
    success "GitHub CI/CD настроен"
}

# Шаг 10: Тестовый деплой
test_deployment() {
    log "=== ШАГ 10: Тестовый деплой ==="
    
    cd ~/Netology/DiplomDevOps/test-app
    
    # Создаем тег
    git tag v1.0.0
    git push origin v1.0.0
    
    log "Тег v1.0.0 создан и отправлен. GitHub Actions запустит деплой автоматически."
    log "Проверьте статус на: https://github.com/Relekt71/DiplomDevOps/actions"
    
    success "Тестовый деплой инициирован"
}

# Главная функция
main() {
    echo "=========================================="
    echo "  DIPLOM DEVOPS - ПОЛНЫЙ DEPLOY"
    echo "=========================================="
    echo ""
    
    check_dependencies
    check_env
    
    deploy_infrastructure
    deploy_registry
    setup_ssh_keys
    install_kubernetes
    post_setup_cluster
    setup_local_kubeconfig
    setup_registry_access
    build_and_push_image
    setup_github_cicd
    test_deployment
    
    echo ""
    echo "=========================================="
    success "DEPLOY ЗАВЕРШЕН УСПЕШНО!"
    echo "=========================================="
    echo ""
    echo "Полезные ссылки:"
    echo "- Приложение: http://$(cat ~/Netology/DiplomDevOps/master_ip.txt):32040/app"
    echo "- Grafana: http://$(cat ~/Netology/DiplomDevOps/master_ip.txt):32040/grafana"
    echo "- GitHub Actions: https://github.com/Relekt71/DiplomDevOps/actions"
    echo ""
}

# Запуск
main "$@"
