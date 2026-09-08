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
  token     = var.yc_token != "" ? var.yc_token : trimspace(file(var.token_file_path))
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.default_zone
}

# Создаем Container Registry
resource "yandex_container_registry" "diploma_registry" {
  name      = var.registry_name
  folder_id = var.folder_id
}

# Создаем сервисный аккаунт для доступа к Registry из кластера
resource "yandex_iam_service_account" "registry_sa" {
  name        = var.registry_sa_name
  description = "Service account for pulling images from Container Registry"
}

# Назначаем роль puller для SA (чтобы K8s мог скачивать образы)
resource "yandex_container_registry_iam_binding" "registry_puller" {
  registry_id = yandex_container_registry.diploma_registry.id
  role        = "container-registry.images.puller"
  members = [
    "serviceAccount:${yandex_iam_service_account.registry_sa.id}",
  ]
}
