output "registry_id" {
  value = yandex_container_registry.diploma_registry.id
}
output "registry_sa_id" {
  value = yandex_iam_service_account.registry_sa.id
}
