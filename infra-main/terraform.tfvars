token_file_path = "/home/relekt/tokens/token.json"
cloud_id        = "b1gecg7g9vaf2vm3jlbv"
folder_id       = "b1gi7d9oo4tihh61hkeb"

# VPC
network_name  = "diploma-network"
subnet_a_cidr = "10.10.0.0/16"
subnet_b_cidr = "10.11.0.0/16"
subnet_d_cidr = "10.12.0.0/16"

# Kubernetes (минимальные ресурсы для экономии)
master_cores     = 2
master_memory    = 4
master_disk_size = 30

worker_count     = 2
worker_cores     = 2
worker_memory    = 2
worker_disk_size = 20