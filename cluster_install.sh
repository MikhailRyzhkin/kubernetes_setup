#!/bin/bash

set -e

# Создание инфраструктуры и генерация инвентарных данных для плейбука ansible kubespray
cd terraform
TF_IN_AUTOMATION=1 terraform init
TF_IN_AUTOMATION=1 terraform apply -auto-approve
bash generate_inventory.sh > ../kubespray_inventory/hosts.ini
bash generate_credentials_velero.sh > ../kubespray_inventory/credentials-velero
bash generate_etc_hosts.sh > ../kubespray_inventory/etc-hosts

# Удаляем данные инвентарников, если были из папки kubespray и копируем туда свежесгенерированные
cd ../
rm -rf kubespray/inventory/mycluster
cp -rfp kubespray_inventory kubespray/inventory/mycluster

# Запускаем ansible плейбук kubespray развёртывания кластера k8s
cd kubespray
ansible-playbook -i inventory/mycluster/hosts.ini --become cluster.yml

# Подменяет локальные адреса на белый кластера из сгененированного конфига kubespray, создаём файл admin.conf для дальнейшего подключчения к нему удалённо
cd ../terraform
MASTER_1_PRIVATE_IP=$(terraform output -json instance_group_masters_private_ips | jq -j ".[0]")
MASTER_1_PUBLIC_IP=$(terraform output -json instance_group_masters_public_ips | jq -j ".[0]")
sed -i -- "s/$MASTER_1_PRIVATE_IP/$MASTER_1_PUBLIC_IP/g" ../kubespray/inventory/mycluster/artifacts/admin.conf

# Создаём конфигурационный каталог для управления кластером и копируем в него конфиг-файл:
mkdir -p ~/.kube 
sudo mkdir -p root/.kube 
mkdir -p /opt/.kube
cd ../
cp kubespray/inventory/mycluster/artifacts/admin.conf ~/.kube/config
sudo cp kubespray/inventory/mycluster/artifacts/admin.conf root/.kube/config
cp kubespray/inventory/mycluster/artifacts/admin.conf /opt/.kube/config
chmod 777 /opt/.kube
chmod 777 /opt/.kube/config

Добавляем сгенерированные хосты в наш локальный hosts-файл:
$ sudo sh -c "cat kubespray_inventory/etc-hosts >> /etc/hosts"

# Проверяем доступность кластера:
echo -n " "
echo -n "======================= Ноды кластера ================================="
kubectl get nodes
echo -n " "
echo -n "======================= Поды кластера ================================="
kubectl get pods -A
echo -n " "
echo -n "Кластер k8s успешно настроен!"