
# Облачный провайдер - Yandex cloud
terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">=0.84.0"
    }
  }
}

# Provider
# Документация по провайдеру: https://registry.terraform.io/providers/yandex-cloud/yandex/latest/docs#configuration-reference
# Настраиваем the Yandex.Cloud provider
# Данные для подключения к провайдеру
provider "yandex" {
  token     = var.yandex_cloud_token
  cloud_id  = var.yandex_cloud_id
  folder_id = var.yandex_folder_id
}


# Network
# Создаём сеть кластера kubernetes
resource "yandex_vpc_network" "k8s-network" {
  name = "k8s-network"
}

# Создаём сеть кластера kubernetes в зоне ru-central1-a
resource "yandex_vpc_subnet" "k8s-subnet-1" {
  name           = "k8s-subnet-1"
  zone           = var.zone[0]
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["192.168.10.0/24"]
  depends_on = [
    yandex_vpc_network.k8s-network,
  ]
}

# Создаём сеть кластера kubernetes в зоне ru-central1-b
resource "yandex_vpc_subnet" "k8s-subnet-2" {
  name           = "k8s-subnet-2"
  zone           = var.zone[1]
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["192.168.20.0/24"]
  depends_on = [
    yandex_vpc_network.k8s-network,
  ]
}

# Создаём сеть кластера kubernetes в зоне ru-central1-c
resource "yandex_vpc_subnet" "k8s-subnet-3" {
  name           = "k8s-subnet-3"
  zone           = var.zone[2]
  network_id     = yandex_vpc_network.k8s-network.id
  v4_cidr_blocks = ["192.168.30.0/24"]
  depends_on = [
    yandex_vpc_network.k8s-network,
  ]
}


# Service accounts
# Создание сервисного аккаунта в яндекс облаке для кластера k8s
resource "yandex_iam_service_account" "admin" {
  name = "admin"
}

resource "yandex_resourcemanager_folder_iam_binding" "editor" {
  folder_id = var.yandex_folder_id
  role = "editor"
  members = [
    "serviceAccount:${yandex_iam_service_account.admin.id}",
  ]
  depends_on = [
    yandex_iam_service_account.admin,
  ]
}

resource "yandex_iam_service_account_static_access_key" "static-access-key" {
  service_account_id = yandex_iam_service_account.admin.id
  depends_on = [
    yandex_iam_service_account.admin,
  ]
}


# Compute instance group for masters
# Создание группы ВМ с ролью будущих мастер нод
resource "yandex_compute_instance_group" "k8s-masters" {
  name               = "k8s-masters"
  service_account_id = yandex_iam_service_account.admin.id
  depends_on = [
    yandex_iam_service_account.admin,
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_vpc_network.k8s-network,
    yandex_vpc_subnet.k8s-subnet-1,
    yandex_vpc_subnet.k8s-subnet-2,
    yandex_vpc_subnet.k8s-subnet-3,
  ]

  instance_template {

    name = "master-{instance.index}"

    resources {
      cores  = 2
      memory = 2
      core_fraction = 100
    }

    boot_disk {
      initialize_params {
        image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04 LTS
        size     = 10
        type     = "network-ssd"
      }
    }

    network_interface {
      network_id = yandex_vpc_network.k8s-network.id
      subnet_ids = [
        yandex_vpc_subnet.k8s-subnet-1.id,
        yandex_vpc_subnet.k8s-subnet-2.id,
        yandex_vpc_subnet.k8s-subnet-3.id,
      ]
      nat = true
    }

    metadata = {
      ssh-keys = "ubuntu:${file("/home/ubuntu/.ssh/mikhail-skillfactory.pub")}"
    }
    
    network_settings {
      type = "STANDARD"
    }
  }

# Количество мастер-нод
  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    zones = [
      var.zone[0],
      var.zone[1],
      var.zone[2],
    ]
  }

  deploy_policy {
    max_unavailable = 3
    max_creating    = 3
    max_expansion   = 3
    max_deleting    = 3
  }
}

# Compute instance group for workers
# Создание группы ВМ с ролью будущих рабочих нод
resource "yandex_compute_instance_group" "k8s-workers" {
  name               = "k8s-workers"
  service_account_id = yandex_iam_service_account.admin.id
  depends_on = [
    yandex_iam_service_account.admin,
    yandex_resourcemanager_folder_iam_binding.editor,
    yandex_vpc_network.k8s-network,
    yandex_vpc_subnet.k8s-subnet-1,
    yandex_vpc_subnet.k8s-subnet-2,
    yandex_vpc_subnet.k8s-subnet-3,
  ]

  instance_template {

    name = "worker-{instance.index}"

    resources {
      cores  = 2
      memory = 2
      core_fraction = 100
    }

    boot_disk {
      initialize_params {
        image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04 LTS
        size     = 10
        type     = "network-hdd"
      }
    }

    network_interface {
      network_id = yandex_vpc_network.k8s-network.id
      subnet_ids = [
        yandex_vpc_subnet.k8s-subnet-1.id,
        yandex_vpc_subnet.k8s-subnet-2.id,
        yandex_vpc_subnet.k8s-subnet-3.id,
      ]
      nat = true
    }

    metadata = {
      ssh-keys = "ubuntu:${file("/home/ubuntu/.ssh/mikhail-skillfactory.pub")}"
    }
    network_settings {
      type = "STANDARD"
    }
  }

# Количество рабочих-нод
  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    zones = [
      var.zone[0],
      var.zone[1],
      var.zone[2],
    ]
  }

  deploy_policy {
    max_unavailable = 3
    max_creating    = 3
    max_expansion   = 3
    max_deleting    = 3
  }
}

# Compute instance group for ingresses
# Создание группы ВМ с ролью будущих сетевых ингресс нод
#resource "yandex_compute_instance_group" "k8s-ingresses" {
#  name               = "k8s-ingresses"
#  service_account_id = yandex_iam_service_account.admin.id
#  depends_on = [
#    yandex_iam_service_account.admin,
#    yandex_resourcemanager_folder_iam_binding.editor,
#    yandex_vpc_network.k8s-network,
#    yandex_vpc_subnet.k8s-subnet-1,
#    yandex_vpc_subnet.k8s-subnet-2,
#    yandex_vpc_subnet.k8s-subnet-3,
#  ]
#
# Целевая ингресс-группа, которая будет работать с балансировщиком
#  load_balancer {
#    target_group_name = "k8s-ingresses"
#  }
#
#  instance_template {
#
#    name = "ingress-{instance.index}"
#
#    resources {
#      cores  = 2
#      memory = 2
#      core_fraction = 20
#    }
#
#    boot_disk {
#      initialize_params {
#        image_id = "fd8vmcue7aajpmeo39kk" # Ubuntu 20.04 LTS
#        size     = 10
#        type     = "network-hdd"
#      }
#    }
#
#    network_interface {
#      network_id = yandex_vpc_network.k8s-network.id
#      subnet_ids = [
#        yandex_vpc_subnet.k8s-subnet-1.id,
#        yandex_vpc_subnet.k8s-subnet-2.id,
#        yandex_vpc_subnet.k8s-subnet-3.id,
#      ]
#      nat = true
#    }
#
#    metadata = {
#      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
#    }
#    network_settings {
#      type = "STANDARD"
#    }
#  }
#
# Количество ингресс-нод
#  scale_policy {
#    fixed_scale {
#      size = 2
#    }
#  }
#
#  allocation_policy {
#    zones = [
#      var.zone[0],
#      var.zone[1],
#      var.zone[2],
#    ]
#  }
#
#  deploy_policy {
#    max_unavailable = 2
#    max_creating    = 2
#    max_expansion   = 2
#    max_deleting    = 2
#  }
#}

# Load balancer for ingresses
# Создание балансировщика трафика для ингресс нод
#resource "yandex_lb_network_load_balancer" "k8s-load-balancer" {
#  name = "k8s-load-balancer"
#  depends_on = [
#    yandex_compute_instance_group.k8s-ingresses,
#  ]
#
#  listener {
#    name = "my-listener"
#    port = 80
#    external_address_spec {
#      ip_version = "ipv4"
#    }
#  }
#
#  attached_target_group {
#    target_group_id = yandex_compute_instance_group.k8s-ingresses.load_balancer.0.target_group_id
#    healthcheck {
#      name = "http"
#      http_options {
#        port = 80
#        path = "/healthz"
#      }
#    }
#  }
#}


# Backet for storing cluster backups
# Создание бакета для хранения бэкапов кластера
#resource "yandex_storage_bucket" "backup-backet" {
#  bucket = "backup-backet"
#  force_destroy = true
#  access_key = yandex_iam_service_account_static_access_key.static-access-key.access_key
#  secret_key = yandex_iam_service_account_static_access_key.static-access-key.secret_key
#  depends_on = [
#    yandex_iam_service_account_static_access_key.static-access-key
#  ]
#}


# Output values
# Вывод данных после создания инфраструктуры для передачи их для работы в ansible
output "instance_group_masters_public_ips" {
  description = "Public IP addresses for master-nodes"
  value = yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.nat_ip_address
}

output "instance_group_masters_private_ips" {
  description = "Private IP addresses for master-nodes"
  value = yandex_compute_instance_group.k8s-masters.instances.*.network_interface.0.ip_address
}

output "instance_group_workers_public_ips" {
  description = "Public IP addresses for worder-nodes"
  value = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.nat_ip_address
}

output "instance_group_workers_private_ips" {
  description = "Private IP addresses for worker-nodes"
  value = yandex_compute_instance_group.k8s-workers.instances.*.network_interface.0.ip_address
}

#output "instance_group_ingresses_public_ips" {
#  description = "Public IP addresses for ingress-nodes"
#  value = yandex_compute_instance_group.k8s-ingresses.instances.*.network_interface.0.nat_ip_address
#}

#output "instance_group_ingresses_private_ips" {
#  description = "Private IP addresses for ingress-nodes"
#  value = yandex_compute_instance_group.k8s-ingresses.instances.*.network_interface.0.ip_address
#}

#output "load_balancer_public_ip" {
#  description = "Public IP address of load balancer"
#  value = yandex_lb_network_load_balancer.k8s-load-balancer.listener.*.external_address_spec.0.address
#}

output "static-key-access-key" {
  description = "Access key for admin user"
  value = yandex_iam_service_account_static_access_key.static-access-key.access_key
}

output "static-key-secret-key" {
  description = "Secret key for admin user"
  value = yandex_iam_service_account_static_access_key.static-access-key.secret_key
  sensitive = true
}
