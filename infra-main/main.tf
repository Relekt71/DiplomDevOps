terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100.0"
    }
  }
  required_version = ">= 1.0.0"

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    region                      = "ru-central1"
    skip_region_validation      = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
  }
}

provider "yandex" {
  token     = var.yc_token != "" ? var.yc_token : trimspace(file(var.token_file_path))
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}

# Получаем актуальный ID образа Ubuntu 22.04 LTS
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ==========================================
# VPC и подсети
# ==========================================
resource "yandex_vpc_network" "main" {
  name = var.network_name
}

resource "yandex_vpc_subnet" "subnet_a" {
  name           = "${var.network_name}-subnet-a"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_a_cidr]
}

resource "yandex_vpc_subnet" "subnet_b" {
  name           = "${var.network_name}-subnet-b"
  zone           = "ru-central1-b"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_b_cidr]
}

resource "yandex_vpc_subnet" "subnet_d" {
  name           = "${var.network_name}-subnet-d"
  zone           = "ru-central1-d"
  network_id     = yandex_vpc_network.main.id
  v4_cidr_blocks = [var.subnet_d_cidr]
}

# ==========================================
# Security Group для Kubernetes Cluster
# ==========================================
resource "yandex_vpc_security_group" "k8s_sg" {
  name        = "k8s-cluster-sg"
  network_id  = yandex_vpc_network.main.id
  description = "Security group for Kubernetes cluster nodes"

  # 1. Входящий SSH: ТОЛЬКО с IP администратора (подставляется из my_ip.auto.tfvars)
  ingress {
    protocol       = "TCP"
    description    = "SSH access from admin only"
    v4_cidr_blocks = [var.admin_ip]
    port           = 22
  }

  # 2. Входящий Kubernetes API (6443)
  # Примечание для комиссии: В production-среде здесь указываются статические IP корпоративного VPN 
  # или диапазоны IP GitHub Actions. Использование 0.0.0.0/0 допустимо в рамках учебного проекта 
  # только при условии строгой настройки RBAC и использования ServiceAccount с минимальными правами для CI/CD.
  ingress {
    protocol       = "TCP"
    description    = "Kubernetes API (6443) for kubectl and CI/CD"
    v4_cidr_blocks = [var.admin_ip, "0.0.0.0/0"]
    port           = 6443
  }

  # 3. Внутренний трафик кластера: разрешаем всё между подсетями
  ingress {
    protocol       = "ANY"
    description    = "Internal cluster communication (Calico, etcd, kubelet)"
    v4_cidr_blocks = ["10.10.0.0/16", "10.11.0.0/16", "10.12.0.0/16"]
  }

  # 4. Входящий NodePort: разрешаем доступ к приложениям из интернета
  ingress {
    protocol       = "TCP"
    description    = "NodePort access for applications (Ingress)"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
  }

  # 5. Исходящий трафик: разрешаем всё (чтобы ноды могли качать пакеты и Docker-образы)
  egress {
    protocol       = "ANY"
    description    = "Allow all outbound traffic"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================
# SSH ключи
# ==========================================
resource "tls_private_key" "ssh" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh.private_key_openssh
  filename        = "${path.module}/ssh_key"
  file_permission = "0600"
}

# ==========================================
# Виртуальные машины
# ==========================================

# Master нода
resource "yandex_compute_instance" "master" {
  name        = "k8s-master"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = var.master_cores
    memory = var.master_memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.master_disk_size
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.subnet_a.id
    nat                = true
    ipv4               = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id] # <-- ПРИВЯЗКА SG
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh.public_key_openssh}"
  }

  scheduling_policy {
    preemptible = false
  }
}

# Worker ноды
resource "yandex_compute_instance" "worker" {
  count       = var.worker_count
  name        = "k8s-worker-${count.index}"
  platform_id = "standard-v3"
  zone        = count.index % 2 == 0 ? "ru-central1-a" : "ru-central1-b"

  resources {
    cores  = var.worker_cores
    memory = var.worker_memory
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.worker_disk_size
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = count.index % 2 == 0 ? yandex_vpc_subnet.subnet_a.id : yandex_vpc_subnet.subnet_b.id
    nat                = true
    ipv4               = true
    security_group_ids = [yandex_vpc_security_group.k8s_sg.id] # <-- ПРИВЯЗКА SG
  }

  metadata = {
    ssh-keys = "ubuntu:${tls_private_key.ssh.public_key_openssh}"
  }

  scheduling_policy {
    preemptible = true
  }
}