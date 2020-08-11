#!/bin/bash
user=${1:-$(whoami)}
ssl_path=/etc/kubernetes/ssl
kube_dir=/home/$user/.kube
host_ip=${2-$(ifconfig $(route | grep '^default' | grep -o '[^ ]*$') | awk '/inet / {print $2}')}

mkdir -p $kube_dir/ssl

sudo cp $ssl_path/ca.pem $kube_dir/ssl/
sudo cp $ssl_path/admin*.pem $kube_dir/ssl/

sudo chmod 664 $ssl_path/*.pem
sudo chown $user:$user $ssl_path/*.pem

kubectl config set-cluster "local" --server=https://$host_ip:6443 --certificate-authority=$kube_dir/ssl/ca.pem
kubectl config set-credentials "admin" --client-certificate=$kube_dir/ssl/admin.pem --client-key=$kube_dir/ssl/admin-key.pem
kubectl config set-context "admin-ctx" --cluster=local --user=admin
kubectl config use-context "admin-ctx"