#!/bin/bash
set -euo pipefail

# ============================================
# DIPLOM DEVOPS - ПОЛНЫЙ DEPLOY SCRIPT (v2)
# ============================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $(date '+%H:%M:%S') - $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $(date '+%H:%M:%S') - $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $(date '+%H:%M:%S') - $1"; }
error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') - $1"; exit 1; }

# Функция ожидания готовности SSH
wait_for_ssh() {
    local host=$1
    local key_path=$2
    local max_attempts=30
    local attempt=1
    
    log "Ожидание доступности SSH на $host..."
    
    while [ $attempt -le $max_attempts ]; do
        if ssh -i "$key_path" -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$host "echo 'SSH ready'" &>/dev/null; then
            success "SSH доступен на $host"
            return 0
        fi
        echo -n "."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    error "SSH не стал доступен после $((max_attempts * 10)) секунд"
}

# Проверка зависимостей
check_dependencies() {
    log "Проверка зависимостей..."
    local deps=("terraform" "ansible" "kubectl" "helm" "docker" "yc" "git" "jq")
    for dep in "${deps[@]}"; do
        if ! command -v $dep &> /dev/null; then
            error "Зависимость $dep не найдена"
        fi
    done
    success "Все зависимости установлены"
}

# Шаг 1: Инфраструктура
deploy_infrastructure() {
    log "=== ШАГ 1: Развертывание инфраструктуры ==="
    cd ~/Netology/DiplomDevOps/infra-main
    
    terraform init -input=false
    terraform apply -auto-approve
    
    MASTER_IP=$(terraform output -raw master_public_ip 2>/dev/null || echo "51.250.7.178")
    echo "$MASTER_IP" > ~/Netology/DiplomDevOps/master_ip.txt
    
    success "Инфраструктура развернута. Master IP: $MASTER_IP"
}

# Шаг 2: Registry
deploy_registry() {
    log "=== ШАГ 2: Создание Container Registry ==="
    cd ~/Netology/DiplomDevOps/infra-registry
    
    terraform init -input=false
    terraform apply -auto-approve
    
    REGISTRY_ID=$(terraform output -raw registry_id)
    SA_ID=$(terraform output -raw registry_sa_id)
    
    echo "$REGISTRY_ID" > ~/Netology/DiplomDevOps/registry_id.txt
    echo "$SA_ID" > ~/Netology/DiplomDevOps/registry_sa_id.txt
    
    success "Registry создан. ID: $REGISTRY_ID"
}

# Шаг 3: Ожидание SSH и проверка подключения
setup_ssh_keys() {
    log "=== ШАГ 3: Проверка SSH подключения ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    if [ ! -f "$SSH_KEY_PATH" ]; then
        error "SSH ключ не найден: $SSH_KEY_PATH"
    fi
    
    chmod 600 "$SSH_KEY_PATH"
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP 'chmod 600 ~/ssh_key'
    
    # Ждем готовности SSH (до 5 минут)
    wait_for_ssh "$MASTER_IP" "$SSH_KEY_PATH"
    
    success "SSH подключен и готов к работе"
}

# Шаг 4: Установка Kubernetes
install_kubernetes() {
    log "=== ШАГ 4: Установка Kubernetes через Kubespray ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    # Копируем приватный ключ на мастер, чтобы Ansible мог управлять нодами
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no "$SSH_KEY_PATH" ubuntu@$MASTER_IP:~/ssh_key
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP "chmod 600 ~/ssh_key && sudo chown ubuntu:ubuntu ~/ssh_key" 

    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'KUBESPRAY_EOF'
set -euo pipefail

log() { echo "[KUBESPRAY] $1"; }

log "Обновление пакетов..."
sudo DEBIAN_FRONTEND=noninteractive apt update -qq
sudo DEBIAN_FRONTEND=noninteractive apt install -y python3-pip python3-venv git

log "Клонирование Kubespray..."
cd ~
if [ ! -d "kubespray" ]; then
    git clone https://github.com/kubernetes-sigs/kubespray.git
fi
cd kubespray
git checkout v2.26.0

log "Создание виртуального окружения..."
python3 -m venv venv
source venv/bin/activate

log "Установка зависимостей..."
pip3 install --upgrade pip -q
pip3 install -r requirements.txt -q
pip3 install ruamel.yaml -q

log "Генерация инвентаря..."
cp -rfp inventory/sample inventory/mycluster

# Исправляем инвентарь (1 мастер, 2 воркера)
cat > inventory/mycluster/hosts.yml << 'INVENTORY_EOF'
all:
  hosts:
    node1:
      ansible_host: 10.10.0.8
      ip: 10.10.0.8
      ansible_user: ubuntu
      ansible_become: yes
      ansible_become_method: sudo
      ansible_become_user: root
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
      ansible_become_flags: '-H -S -p ""'
    node2:
      ansible_host: 10.10.0.29
      ip: 10.10.0.29
      ansible_user: ubuntu
      ansible_become: yes
      ansible_become_method: sudo
      ansible_become_user: root
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
      ansible_become_flags: '-H -S -p ""'
    node3:
      ansible_host: 10.11.0.3
      ip: 10.11.0.3
      ansible_user: ubuntu
      ansible_become: yes
      ansible_become_method: sudo
      ansible_become_user: root
      ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
      ansible_become_flags: '-H -S -p ""'
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
INVENTORY_EOF

cat > inventory/mycluster/group_vars/all/all.yml << 'VARS_EOF'
kubelet_cgroup_driver: systemd
container_manager: containerd
kubelet_fail_swap_on: true
ignore_assert_errors: true
VARS_EOF

log "Запуск установки Kubernetes (это займет 15-25 минут)..."
ansible-playbook -i inventory/mycluster/hosts.yml \
  -b -v \
  --private-key=~/ssh_key \
  --user=ubuntu \
  --ssh-extra-args="-tt" \
  cluster.yml || {
    log "Повторный запуск после ошибки..."
    ansible-playbook -i inventory/mycluster/hosts.yml \
      -b -v \
      --private-key=~/ssh_key \
      --user=ubuntu \
      cluster.yml
  }

log "Настройка kubectl..."
mkdir -p ~/.kube
sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config

log "Проверка кластера..."
kubectl get nodes

log "Kubernetes установлен успешно!"
KUBESPRAY_EOF
    
    success "Kubernetes установлен"
}

# Шаг 5: Пост-настройка
post_setup_cluster() {
    log "=== ШАГ 5: Пост-настройка кластера ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP << 'POSTSETUP_EOF'
set -euo pipefail

log() { echo "[POST-SETUP] $1"; }

log "Установка Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

log "Добавление репозиториев..."
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

log "Установка Ingress Controller..."
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=LoadBalancer || true

sleep 30

log "Создание манифеста приложения..."
cat > ~/test-app.yaml << 'APP_EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: diploma-test-app
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
    - port: 80
      targetPort: 80
      nodePort: 32042
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: diploma-app-ingress
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /app
        pathType: Prefix
        backend:
          service:
            name: diploma-test-app-svc
            port:
              number: 80
APP_EOF

kubectl apply -f ~/test-app.yaml

log "Установка мониторинга..."
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
MONITORING_EOF

helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  -f ~/monitoring-values.yaml

log "Пост-настройка завершена!"
POSTSETUP_EOF
    
    success "Кластер настроен"
}

# Шаг 6: Локальный kubeconfig
setup_local_kubeconfig() {
    log "=== ШАГ 6: Настройка локального kubeconfig ==="
    
    MASTER_IP=$(cat ~/Netology/DiplomDevOps/master_ip.txt)
    SSH_KEY_PATH=~/Netology/DiplomDevOps/infra-main/ssh_key
    
    scp -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no ubuntu@$MASTER_IP:~/.kube/config ~/.kube/config
    
    sed -i 's|server: https://.*:6443|server: https://'"$MASTER_IP"':6443|g' ~/.kube/config
    sed -i '/certificate-authority-data:/d' ~/.kube/config
    sed -i '/server: https:\/\/'"$MASTER_IP"':6443/a\    insecure-skip-tls-verify: true' ~/.kube/config
    
    chmod 600 ~/.kube/config
    
    success "Локальный kubeconfig настроен"
}

# Шаг 7: Доступ к Registry
setup_registry_access() {
    log "=== ШАГ 7: Настройка доступа к Registry ==="
    
    SA_ID=$(cat ~/Netology/DiplomDevOps/registry_sa_id.txt)
    REGISTRY_ID=$(cat ~/Netology/DiplomDevOps/registry_id.txt)
    
    yc iam key create --service-account-id $SA_ID --output ~/Netology/DiplomDevOps/registry-key.json
    yc container registry add-access-binding $REGISTRY_ID \
      --role container-registry.images.admin \
      --service-account-id $SA_ID
    yc container registry configure-docker
    
    success "Доступ к Registry настроен"
}

# Шаг 8: Сборка образа
build_and_push_image() {
    log "=== ШАГ 8: Сборка Docker-образа ==="
    
    cd ~/Netology/DiplomDevOps/test-app
    REGISTRY_ID=$(cat ~/Netology/DiplomDevOps/registry_id.txt)
    
    docker build -t diploma-test-app:v1.0.0 .
    docker tag diploma-test-app:v1.0.0 cr.yandex/$REGISTRY_ID/diploma-test-app:v1.0.0
    docker push cr.yandex/$REGISTRY_ID/diploma-test-app:v1.0.0
    
    success "Образ собран и отправлен"
}

# Главная функция
main() {
    echo "=========================================="
    echo "  DIPLOM DEVOPS - ПОЛНЫЙ DEPLOY v2"
    echo "=========================================="
    echo ""
    
    check_dependencies
    deploy_infrastructure
    deploy_registry
    setup_ssh_keys
    install_kubernetes
    post_setup_cluster
    setup_local_kubeconfig
    setup_registry_access
    build_and_push_image
    
    echo ""
    echo "=========================================="
    success "DEPLOY ЗАВЕРШЕН УСПЕШНО!"
    echo "=========================================="
    echo ""
    echo "Ссылки:"
    echo "- Приложение: http://$(cat ~/Netology/DiplomDevOps/master_ip.txt):32040/app"
    echo "- Grafana: http://$(cat ~/Netology/DiplomDevOps/master_ip.txt):32040/grafana"
    echo ""
}

main "$@"
