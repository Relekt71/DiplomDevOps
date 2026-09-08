variable "yc_token" {
  type      = string
  sensitive = true
  default   = ""
}
variable "token_file_path" {
  type    = string
  default = "/home/relekt/tokens/token.json"
}
variable "cloud_id" {
  type = string
}
variable "folder_id" {
  type = string
}
variable "default_zone" {
  type    = string
  default = "ru-central1-a"
}
variable "registry_name" {
  type    = string
  default = "diploma-registry"
}
variable "registry_sa_name" {
  type    = string
  default = "registry-puller-sa"
}
