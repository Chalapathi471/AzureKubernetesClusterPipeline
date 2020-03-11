variable client_id {}
variable client_secret {}
variable ssh_public_key {}

variable environment {
    default = "dev"
}

variable location {
    default = "eastus"
}

variable node_count {
  default = 3
}

variable dns_prefix {
  default = "k8stest"
}

variable cluster_name {
  default = "aks-terraform-cluster"
}

variable resource_group {
  default = "kubernetes-terraform-rg"
}