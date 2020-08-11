#!/bin/bash

og_dir=$(pwd)
out_dir=./out
kube_dir=/etc/kubernetes
cni_dir=/etc/cni/net.d
owner=${1:-tempadmin}
host_ip=${2-$(ifconfig $(route | grep '^default' | grep -o '[^ ]*$') | awk '/inet / {print $2}')}

cd $out_dir

mkdir -p $kube_dir/ssl
mkdir -p $kube_dir/manifests

# manifests
echo deploying manifests
cp manifests/*.yaml $kube_dir/manifests

# configs
echo deploying config
cp config/control-plane/*.yaml $kube_dir
cp config/kubeconfig/*.yaml $kube_dir

#cp config/kubeconfig/admin.yaml /home/$owner/.kube/config
mkdir -p /home/$owner/.kube/ssl
chown -R $owner:$owner /home/$owner/.kube
cp certs/*.pem /home/$owner/.kube/ssl/

mkdir -p $kube_dir/flannel
cp config/flannel/*.json $kube_dir/flannel

mkdir -p $cni_dir
cp config/flannel/cni-conf.json /etc/cni/net.d/10-flannel.conflist

# certs
echo deploying certs
cp certs/*.pem $kube_dir/ssl

# cni
echo deploying CNI plugins
mkdir -p /opt/cni/bin
cp bin/cni/* /opt/cni/bin

# etcd
echo deploying etcd
cp systemd-units/etcd-member.service /etc/systemd/system

# kubelet
echo deploying kubelet
chown root:root bin/kubelet
cp bin/kubelet /usr/local/bin
cp systemd-units/kubelet.service /etc/systemd/system

# kubectl
echo deploying kubectl
chown root:root bin/kubectl
cp bin/kubectl /usr/local/bin

# start services
systemctl daemon-reload

echo restarting docker
systemctl restart docker.service

echo starting etcd
systemctl enable etcd-member.service
systemctl start etcd-member.service

# flannel
echo bootstrapping flannel
sleep 1s
network_cfg=$(cat config/flannel/net-conf.json)
docker run --rm --name etcd-bootstrap quay.io/coreos/etcd:latest etcdctl --endpoints=http://$host_ip:2379 set /coreos.com/network/config "$network_cfg"

echo starting kubelet
systemctl enable kubelet.service
systemctl start kubelet.service

cd $og_dir