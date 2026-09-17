#!/bin/bash
set -e

echo "🔧 Генерация инвентаря Kubespray из Terraform outputs..."

# Переходим в директорию infra-main
cd "$(dirname "$0")/../infra-main"

# Проверяем, что Terraform state существует
if [ ! -f terraform.tfstate ]; then
    echo "❌ Ошибка: terraform.tfstate не найден. Сначала выполните terraform apply."
    exit 1
fi

# Получаем IP из Terraform outputs
MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip 2>/dev/null)
MASTER_PUBLIC_IP=$(terraform output -raw master_public_ip 2>/dev/null)
WORKER_IPS_JSON=$(terraform output -json worker_private_ips 2>/dev/null)

if [ -z "$MASTER_PRIVATE_IP" ] || [ -z "$WORKER_IPS_JSON" ]; then
    echo "❌ Ошибка: не удалось получить IP из Terraform outputs."
    exit 1
fi

echo "✅ Получены IP:"
echo "  Master (private): $MASTER_PRIVATE_IP"
echo "  Master (public): $MASTER_PUBLIC_IP"

# Парсим JSON с IP воркеров
WORKER_IPS=$(echo "$WORKER_IPS_JSON" | python3 -c "import sys, json; ips = json.load(sys.stdin); print('\n'.join(ips))")

echo "  Workers:"
echo "$WORKER_IPS" | while read ip; do echo "    - $ip"; done

# Создаём директорию для инвентаря
INVENTORY_DIR="$(dirname "$0")/../k8s/kubespray-inventory"
mkdir -p "$INVENTORY_DIR"

# Генерируем инвентарь динамически
cat > "$INVENTORY_DIR/hosts.yml" << INVENTORY
all:
  hosts:
    node1:
      ansible_host: $MASTER_PRIVATE_IP
      ip: $MASTER_PRIVATE_IP
      ansible_user: ubuntu
      ansible_become: yes
$(echo "$WORKER_IPS" | awk '{print "    node"NR+1":\n      ansible_host: "$0"\n      ip: "$0"\n      ansible_user: ubuntu\n      ansible_become: yes"}')
  children:
    kube_control_plane:
      hosts:
        node1:
    kube_node:
      hosts:
        node1:
$(echo "$WORKER_IPS" | awk '{print "        node"NR+1":"}')
    etcd:
      hosts:
        node1:
    k8s_cluster:
      children:
        kube_control_plane:
        kube_node:
INVENTORY

echo ""
echo "✅ Инвентарь сгенерирован: $INVENTORY_DIR/hosts.yml"
echo ""
cat "$INVENTORY_DIR/hosts.yml"
