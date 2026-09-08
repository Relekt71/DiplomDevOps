terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.100.0"
    }
  }
  required_version = ">= 1.0.0"
}

provider "yandex" {
  # Если yc_token не передан, читаем из файла
  token     = var.yc_token != "" ? var.yc_token : trimspace(file(var.token_file_path))
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}

# ============================================
# 1. Сервисный аккаунт для управления бакетом
# ============================================
resource "yandex_iam_service_account" "bucket_sa" {
  name        = "terraform-bucket-sa"
  description = "Service account for managing S3 bucket"
}

# Минимальные права для управления бакетом
resource "yandex_resourcemanager_folder_iam_member" "bucket_sa_storage_admin" {
  folder_id = var.folder_id
  role      = "storage.admin"
  member    = "serviceAccount:${yandex_iam_service_account.bucket_sa.id}"
}

# Статический ключ для S3 backend
resource "yandex_iam_service_account_static_access_key" "bucket_sa_static_key" {
  service_account_id = yandex_iam_service_account.bucket_sa.id
  description        = "Static access key for S3 backend"
}

# ============================================
# 2. Сервисный аккаунт для инфраструктуры
# ============================================
resource "yandex_iam_service_account" "infra_sa" {
  name        = "terraform-infra-sa"
  description = "Service account for infrastructure management"
}

# Минимальные права для создания VPC
resource "yandex_resourcemanager_folder_iam_member" "infra_sa_vpc_admin" {
  folder_id = var.folder_id
  role      = "vpc.admin"
  member    = "serviceAccount:${yandex_iam_service_account.infra_sa.id}"
}

# Права для управления Kubernetes


# Права для создания Compute instances (для worker nodes)
#esource "yandex_resourcemanager_folder_iam_member" "infra_sa_compute_admin" {
#  folder_id = var.folder_id
#  role      = "compute.admin"
# member    = "serviceAccount:${yandex_iam_service_account.infra_sa.id}"
#}

# Права для управления балансировщиками
resource "yandex_resourcemanager_folder_iam_member" "infra_sa_lb_admin" {
  folder_id = var.folder_id
  role      = "load-balancer.admin"
  member    = "serviceAccount:${yandex_iam_service_account.infra_sa.id}"
}

# Права для чтения из Container Registry
resource "yandex_resourcemanager_folder_iam_member" "infra_sa_cr_puller" {
  folder_id = var.folder_id
  role      = "container-registry.images.puller"
  member    = "serviceAccount:${yandex_iam_service_account.infra_sa.id}"
}

# Статический ключ для infra SA (будем использовать в основной конфигурации)
resource "yandex_iam_service_account_static_access_key" "infra_sa_static_key" {
  service_account_id = yandex_iam_service_account.infra_sa.id
  description        = "Static access key for infrastructure management"
}

# ============================================
# 3. S3 бакет для Terraform state
# ============================================
resource "yandex_storage_bucket" "terraform_state" {
  bucket = var.bucket_name

  access_key = yandex_iam_service_account_static_access_key.bucket_sa_static_key.access_key
  secret_key = yandex_iam_service_account_static_access_key.bucket_sa_static_key.secret_key

  versioning {
    enabled = true
  }

  acl = "private"
}