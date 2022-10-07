terraform {
  required_providers {
    nutanix = {
      source  = "nutanix/nutanix"
      version = "1.6.1"
    }
  }
}

provider "nutanix" {
  username = var.user
  password = var.password
  endpoint = var.endpoint # prism central endpoint
  insecure = true
}

#pull desired cluster data
data "nutanix_cluster" "cluster"{
  name = var.cluster_name
}

#pull desired subnet data
data "nutanix_subnet" "subnet"{
  subnet_name = var.subnet_name
}

resource "nutanix_karbon_cluster" "k8scluster" {
  name       = var.k8sclu_name
  version    = "1.22.9-0"
  storage_class_config {
    reclaim_policy = "Delete"
    volumes_config {
      file_system                = "ext4"
      flash_mode                 = false
      password                   = var.password
      prism_element_cluster_uuid = data.nutanix_cluster.cluster.id
      storage_container          = "Default"
      username                   = var.user
    }
  }
  cni_config {
    node_cidr_mask_size = 24
    pod_ipv4_cidr       = "172.20.0.0/16"
    service_ipv4_cidr   = "172.19.0.0/16"
  }
  worker_node_pool {
    node_os_version = "ntnx-1.3"
    num_instances   = 1
    ahv_config {
      network_uuid               = data.nutanix_subnet.subnet.id
      prism_element_cluster_uuid = data.nutanix_cluster.cluster.id
    }
  }
  etcd_node_pool {
    node_os_version = "ntnx-1.3"
    num_instances   = 1
    ahv_config {

      network_uuid               = data.nutanix_subnet.subnet.id
      prism_element_cluster_uuid = data.nutanix_cluster.cluster.id
    }
  }
  master_node_pool {
    node_os_version = "ntnx-1.3"
    num_instances   = 1
    ahv_config {
      network_uuid               = data.nutanix_subnet.subnet.id
      prism_element_cluster_uuid = data.nutanix_cluster.cluster.id
    }
  }

  provisioner "local-exec" {
    command = "export KUBECONFIG=$(pwd)/kubeconfig"
  }
}

# Get kubeconfig based on the user input
data "nutanix_karbon_cluster_kubeconfig" "configbyname" {
    karbon_cluster_name = nutanix_karbon_cluster.k8scluster.name
}

data "template_file" "kubeconfig" {
  template       = "${file("${path.module}/kubeconfig.tftpl")}"
  vars = {
    access_token           = data.nutanix_karbon_cluster_kubeconfig.configbyname.access_token
    cluster_ca_certificate = data.nutanix_karbon_cluster_kubeconfig.configbyname.cluster_ca_certificate
    cluster_url            = data.nutanix_karbon_cluster_kubeconfig.configbyname.cluster_url
    karbon_cluster_name    = data.nutanix_karbon_cluster_kubeconfig.configbyname.karbon_cluster_name
  }
}

resource "local_file" "foo" {
    content  = data.template_file.kubeconfig.rendered
    filename = "${path.module}/kubeconfig"
}
