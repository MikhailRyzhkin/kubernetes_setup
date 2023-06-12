
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
}
