provider "azurerm" {
   version = "~>2.0"
   features {}
}

provider "helm" {
  kubernetes {
    host     = "${azurerm_kubernetes_cluster.terraform-k8s.kube_config.0.host}"
    client_key             = "${base64decode(azurerm_kubernetes_cluster.terraform-k8s.kube_config.0.client_key)}"
    client_certificate     = "${base64decode(azurerm_kubernetes_cluster.terraform-k8s.kube_config.0.client_certificate)}"
    cluster_ca_certificate = "${base64decode(azurerm_kubernetes_cluster.terraform-k8s.kube_config.0.cluster_ca_certificate)}"
  }
}

resource "azurerm_resource_group" "resource_group" {
  name     = "${var.resource_group}_${var.environment}"
  location = var.location
}

resource "azurerm_virtual_network" "virtual_network" {
  name                =  var.virtual_network_name
  location            =  var.location
  resource_group_name =  azurerm_resource_group.resource_group.name
  address_space       =  ["10.1.0.0/16"]
}

resource "azurerm_subnet" "akssubnet" {
  name                      = "akssubnet"
  resource_group_name       = azurerm_resource_group.resource_group.name
  address_prefix            = "10.1.1.0/24"
  virtual_network_name      = azurerm_virtual_network.virtual_network.name
}

resource "azurerm_subnet" "acisubnet" {
  name                 = "acisubnet"
  resource_group_name  = azurerm_resource_group.resource_group.name
  virtual_network_name = azurerm_virtual_network.virtual_network.name
  address_prefix       = "10.1.2.0/24"

  # Designate subnet to be used by ACI
  delegation {
    name = "aci-delegation"

    service_delegation {
      name    = "Microsoft.ContainerInstance/containerGroups"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = azurerm_resource_group.resource_group.location


  security_rule {
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks-nsg" {
  subnet_id                 = azurerm_subnet.akssubnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_subnet_network_security_group_association" "aci-nsg" {
  subnet_id                 = azurerm_subnet.acisubnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "random_id" "log_analytics_workspace_name_suffix" {
    byte_length = 8
}

resource "azurerm_log_analytics_workspace" "test" {
    # The WorkSpace name has to be unique across the whole of azure, not just the current subscription/tenant.
    name                = "${var.log_analytics_workspace_name}-${random_id.log_analytics_workspace_name_suffix.dec}"
    location            = var.location
    resource_group_name = azurerm_resource_group.resource_group.name
    sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_solution" "test" {
    solution_name         = "ContainerInsights"
    location              = azurerm_log_analytics_workspace.test.location
    resource_group_name   = azurerm_resource_group.resource_group.name
    workspace_resource_id = azurerm_log_analytics_workspace.test.id
    workspace_name        = azurerm_log_analytics_workspace.test.name

    plan {
        publisher = "Microsoft"
        product   = "OMSGallery/ContainerInsights"
    }
}

resource "azurerm_kubernetes_cluster" "terraform-k8s" {
  name                = "${var.cluster_name}_${var.environment}"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = var.dns_prefix
  kubernetes_version  = "1.14.8"

  linux_profile {
    admin_username = "ubuntu"

    ssh_key {
      key_data = file(var.ssh_public_key)
    }
  }

  default_node_pool {
    name       = "agentpool"
    node_count = var.node_count
    vm_size    = "Standard_DS1_v2"
    vnet_subnet_id  = "${azurerm_subnet.akssubnet.id}"
  }

  addon_profile {
    aci_connector_linux {
      enabled     = true
      subnet_name = "${azurerm_subnet.acisubnet.name}"
    }
    oms_agent {
      enabled                    = true
      log_analytics_workspace_id = azurerm_log_analytics_workspace.test.id
    }
    # http_application_routing{
    #   enabled = "true"
    # }
  }

  service_principal {
    client_id     = var.client_id
    client_secret = var.client_secret
  }

  role_based_access_control {
    enabled = true
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    Environment = var.environment
  }
}

resource "helm_release" "ingress" {
    name      = "ingress"
    chart     = "stable/nginx-ingress"
    namespace = "kube-system"

    set {
        name  = "rbac.create"
        value = "true"
    }
}

terraform {
  backend "azurerm" {
    # storage_account_name="<<storage_account_name>>" #OVERRIDE in TERRAFORM init
    # access_key="<<storage_account_key>>" #OVERRIDE in TERRAFORM init
    # key="<<env_name.k8s.tfstate>>" #OVERRIDE in TERRAFORM init
    # container_name="<<storage_account_container_name>>" #OVERRIDE in TERRAFORM init
  }
}

