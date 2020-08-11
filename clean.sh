#!/bin/bash
systemctl stop kubelet
systemctl disable kubelet
systemctl stop etcd-member
systemctl disable etcd-member
docker stop $(docker ps -a -q)
docker rm $(docker ps -a -q)
rm -rf /etc/kubernetes
rm -rf /etc/cni
rm /etc/systemd/system/etcd-member.service
rm /etc/systemd/system/kubelet.service
rm /usr/local/bin/kubelet
rm /usr/local/bin/kubectl
rm -rf /var/lib/etcd
rm -rf /run/flannel