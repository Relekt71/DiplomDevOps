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

# VPC
variable "network_name" {
  description = "VPC network name"
  type        = string
  default     = "diploma-network"
}

variable "subnet_a_cidr" {
  description = "CIDR block for subnet A"
  type        = string
  default     = "10.10.0.0/16"
}

variable "subnet_b_cidr" {
  description = "CIDR block for subnet B"
  type        = string
  default     = "10.11.0.0/16"
}

variable "subnet_d_cidr" {
  description = "CIDR block for subnet D"
  type        = string
  default     = "10.12.0.0/16"
}

# Kubernetes instances
variable "master_cores" {
  description = "CPU cores for master node"
  type        = number
  default     = 2
}

variable "master_memory" {
  description = "Memory (GB) for master node"
  type        = number
  default     = 4
}

variable "master_disk_size" {
  description = "Disk size (GB) for master node"
  type        = number
  default     = 30
}

variable "worker_count" {
  description = "Number of worker nodes"
  type        = number
  default     = 2
}

variable "worker_cores" {
  description = "CPU cores for worker nodes"
  type        = number
  default     = 2
}

variable "worker_memory" {
  description = "Memory (GB) for worker nodes"
  type        = number
  default     = 2
}

variable "worker_disk_size" {
  description = "Disk size (GB) for worker nodes"
  type        = number
  default     = 20
}