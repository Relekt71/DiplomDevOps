#!/bin/bash
set -e

echo "Generating Kubespray inventory from Terraform outputs..."

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$REPO_ROOT/infra-main"

if [ ! -d ".terraform" ]; then
    echo "Terraform is not initialized. Running terraform init..."
    terraform init
fi

MASTER_PRIVATE_IP=$(terraform output -raw master_private_ip 2>/dev/null)
MASTER_PUBLIC_IP=$(terraform output -raw master_public_ip 2>/dev/null)
WORKER_IPS_JSON=$(terraform output -json worker_private_ips 2>/dev/null)

if [ -z "$MASTER_PRIVATE_IP" ] || [ -z "$WORKER_IPS_JSON" ]; then
    echo "Error: failed to get IPs from Terraform outputs."
    echo "Make sure the infrastructure is deployed (terraform apply was executed)."
    exit 1
fi

echo "Received IPs:"
echo "  Master (private): $MASTER_PRIVATE_IP"
echo "  Master (public): $MASTER_PUBLIC_IP"

WORKER_IPS=$(echo "$WORKER_IPS_JSON" | python3 -c "import sys, json; ips = json.load(sys.stdin); print('\n'.join(ips))")

echo "  Workers:"
echo "$WORKER_IPS" | while read ip; do echo "    - $ip"; done

INVENTORY_DIR="$REPO_ROOT/k8s/kubespray-inventory"
mkdir -p "$INVENTORY_DIR"

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
echo "Inventory generated: $INVENTORY_DIR/hosts.yml"
echo ""
cat "$INVENTORY_DIR/hosts.yml"
