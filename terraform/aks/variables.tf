variable client_id {
}
variable client_secret {
}
 variable ssh_public_key {
 }

variable environment {
    default = "dev"
}

variable location {
    default = "eastus"
}

variable node_count {
  default = 1
}



variable dns_prefix {
  default = "k8stest"
}

variable cluster_name {
  default = "aks-terraform-cluster1"
}

variable resource_group {
  default = "kubernetes-terraform-rg1"
}

variable virtual_network_name {
  default = "k8_vnet"
}

variable nsg_name {
  default = "k8_nsg"
}

variable subnet_name {
  default = "K8_subnet"
}

variable "log_analytics_workspace_name" {
  default = "k8loganalyname5we79327932798392473"
}
