variable "yc_token" {
  description = "Yandex Cloud OAuth token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "token_file_path" {
  description = "Path to Yandex Cloud token file"
  type        = string
  default     = "/home/relekt/tokens/token.json"
}

variable "cloud_id" {
  description = "Yandex Cloud ID"
  type        = string
}

variable "folder_id" {
  description = "Yandex Cloud Folder ID"
  type        = string
}

variable "default_zone" {
  description = "Default availability zone"
  type        = string
  default     = "ru-central1-a"
}

variable "sa_name" {
  description = "Service account name"
  type        = string
  default     = "terraform-sa"
}

variable "sa_description" {
  description = "Service account description"
  type        = string
  default     = "Service account for Terraform"
}

variable "bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
}