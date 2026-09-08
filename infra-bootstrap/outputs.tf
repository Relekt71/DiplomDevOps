# ============================================
# Outputs для bucket SA
# ============================================
output "bucket_sa_id" {
  description = "Bucket service account ID"
  value       = yandex_iam_service_account.bucket_sa.id
}

output "bucket_access_key" {
  description = "Static access key for S3 bucket"
  value       = yandex_iam_service_account_static_access_key.bucket_sa_static_key.access_key
  sensitive   = true
}

output "bucket_secret_key" {
  description = "Static secret key for S3 bucket"
  value       = yandex_iam_service_account_static_access_key.bucket_sa_static_key.secret_key
  sensitive   = true
}

output "bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = yandex_storage_bucket.terraform_state.bucket
}

# ============================================
# Outputs для infra SA
# ============================================
output "infra_sa_id" {
  description = "Infrastructure service account ID"
  value       = yandex_iam_service_account.infra_sa.id
}

output "infra_access_key" {
  description = "Static access key for infrastructure SA"
  value       = yandex_iam_service_account_static_access_key.infra_sa_static_key.access_key
  sensitive   = true
}

output "infra_secret_key" {
  description = "Static secret key for infrastructure SA"
  value       = yandex_iam_service_account_static_access_key.infra_sa_static_key.secret_key
  sensitive   = true
}