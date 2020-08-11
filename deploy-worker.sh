#!/bin/bash

og_dir=$(pwd)
out_dir=./out
kube_dir=/etc/kubernetes
cni_dir=/etc/cni/net.d
user=$1
master_ip=$2

if [ -z "$user" ]; then
  echo "user name not provided. e.g. sudo ./deploy-worker.sh myuser 10.0.10.100"
  exit 1
fi

if [ -z "$master_ip" ]; then
  echo "master IP not provided. e.g. sudo ./deploy-worker.sh myuser 10.0.10.100"
  exit 1
fi

cd $out_dir
mkdir -p $kube_dir/ssl
mkdir -p $kube_dir/manifests
mkdir -p $kube_dir/flannel
mkdir -p $cni_dir
mkdir -p /opt/cni/bin

# flannel
echo deploying CNI
cp manifests/flannel.yaml $kube_dir/manifests
cp config/flannel/*.json $kube_dir/flannel
cp config/flannel/cni-conf.json /etc/cni/net.d/10-flannel.conflist
cp bin/cni/* /opt/cni/bin

# kube-proxy
echo deploying kube-proxy
cp manifests/kube-proxy.yaml $kube_dir/manifests
cp config/control-plane/kube-proxy-config.yaml $kube_dir
cp config/kubeconfig/admin.yaml $kube_dir

# kubelet
echo deploying kubelet
chown root:root bin/kubelet
cp bin/kubelet /usr/local/bin
cp systemd-units/kubelet.service /etc/systemd/system
cp config/control-plane/kubelet-config.yaml $kube_dir
cp config/kubeconfig/kubelet.yaml $kube_dir

# certs
echo deploying certs
cp certs/*.pem $kube_dir/ssl

# start services
systemctl daemon-reload

echo restarting docker
systemctl restart docker.service

# flannel
echo bootstrapping flannel
sleep 1s
network_cfg=$(cat config/flannel/net-conf.json)
docker run --rm --name etcd-bootstrap quay.io/coreos/etcd:latest etcdctl --endpoints=http://$master_ip:2379 set /coreos.com/network/config "$network_cfg"

echo starting kubelet
systemctl enable kubelet.service
systemctl start kubelet.service

cd $og_dir
