# VPC outputs
output "network_id" {
  description = "VPC Network ID"
  value       = yandex_vpc_network.main.id
}

output "subnet_a_id" {
  description = "Subnet A ID"
  value       = yandex_vpc_subnet.subnet_a.id
}

output "subnet_b_id" {
  description = "Subnet B ID"
  value       = yandex_vpc_subnet.subnet_b.id
}

output "subnet_d_id" {
  description = "Subnet D ID"
  value       = yandex_vpc_subnet.subnet_d.id
}

# Kubernetes outputs
output "master_public_ip" {
  description = "Master node public IP"
  value       = yandex_compute_instance.master.network_interface[0].nat_ip_address
}

output "master_private_ip" {
  description = "Master node private IP"
  value       = yandex_compute_instance.master.network_interface[0].ip_address
}

output "worker_private_ips" {
  description = "Worker nodes private IPs"
  value       = yandex_compute_instance.worker[*].network_interface[0].ip_address
}

output "ssh_private_key_path" {
  description = "Path to SSH private key"
  value       = local_file.private_key.filename
}
