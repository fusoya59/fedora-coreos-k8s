#!/bin/bash
host_name=${HOST_NAME_OVERRIDE:-$(hostname | awk '{print tolower($0)}')}
host_ip=${HOST_IP_OVERRIDE:-$(ifconfig $(route | grep '^default' | grep -o '[^ ]*$') | awk '/inet / {print $2}')}
user=$1
master_ip=$2

if [ -z "$user" ]; then
  echo "user name not provided. e.g. sudo ./build-worker.sh myuser 10.0.10.100"
  exit 1
fi

if [ -z "$master_ip" ]; then
  echo "master IP not provided. e.g. sudo ./build-worker.sh myuser 10.0.10.100"
  exit 1
fi

pwd_dir=$(pwd)
out_dir=./out

# runtime versions
k8s_version=v1.18.6
flannel_version=v0.12.0
kubelet_version=v0.2.7
cni_version=v0.8.6
etcd_version=latest

# k8s IP networks
pod_cidr=10.240.0.0/12
service_ip=10.100.0.1
service_cidr=10.100.0.0/16
cluster_dns=10.100.0.10

# endpoints
etcd_endpoints=http://$master_ip:2379
api_server_endpoint=https://$master_ip:6443

# paths
k8s_base_path=/etc/kubernetes
k8s_ssl_path=$k8s_base_path/ssl

# cert expiration days
expire_days=3650

cgroup_driver=$(echo $(docker info 2>/dev/null | sed -n 's/Cgroup Driver: \(\w*\)/\1/p'))

resolve_and_save() {
  infile=$1
  outfile=$2
  awk "{gsub(\"{K8S_VERSION}\", \"$k8s_version\"); \
        gsub(\"{FLANNEL_VERSION}\",\"$flannel_version\"); \
        gsub(\"{ETCD_VERSION}\",\"$etcd_version\"); \
        gsub(\"{K8S_BASE_PATH}\",\"$k8s_base_path\"); \
        gsub(\"{K8S_SSL_PATH}\",\"$k8s_ssl_path\"); \
        gsub(\"{CNI_PATH}\",\"$cni_path\"); \
        gsub(\"{POD_CIDR}\",\"$pod_cidr\"); \
        gsub(\"{SERVICE_CIDR}\",\"$service_cidr\"); \
        gsub(\"{CLUSTER_DNS}\",\"$cluster_dns\"); \
        gsub(\"{HOST_NAME}\",\"$host_name\"); \
        gsub(\"{HOST_IP}\",\"$host_ip\"); \
        gsub(\"{ETCD_ENDPOINTS}\",\"$etcd_endpoints\"); \
        gsub(\"{API_SERVER_ENDPOINT}\",\"$api_server_endpoint\"); \
        gsub(\"{EXPIRE_DAYS}\",\"$expire_days\"); \
        gsub(\"{SERVICE_IP}\",\"$service_ip\"); \
        gsub(\"{CGROUP_DRIVER}\",\"$cgroup_driver\"); \
        print}" $infile > $outfile
}

gen_cert() {
  certname=$1
  cn=$2
  extfile=$3
  optargs=$4
  openssl genrsa -out $certname-key.pem 2048
  openssl req -new -key $certname-key.pem -out $certname.csr -subj "/CN=$cn" -config $extfile $optargs
  openssl x509 -req -in $certname.csr -CA ca.pem -CAkey ca-key.pem -CAcreateserial -out $certname.pem -days $expire_days -extensions v3_req -extfile $extfile
}

mkdir -p $out_dir/manifests
mkdir -p $out_dir/config/flannel
mkdir -p $out_dir/config/kubeconfig
mkdir -p $out_dir/config/control-plane
mkdir -p $out_dir/config/ssl
mkdir -p $out_dir/certs
mkdir -p $out_dir/systemd-units
mkdir -p $out_dir/bin/cni

cd $out_dir

# download kubelet
if [ -f "bin/kubelet" ]; then
  echo Kubelet already downloaded
else
  echo Downloading kubelet
  curl -sSLO https://storage.googleapis.com/kubernetes-release/release/$k8s_version/bin/linux/amd64/kubelet
  chmod +x kubelet
  mv kubelet bin
fi

# download cni plugins
if  [ -f "bin/cni/flannel" ]; then
  echo CNI plugins already downloaded
else
  echo Downloading CNI plugins
  curl -sSL "https://github.com/containernetworking/plugins/releases/download/$cni_version/cni-plugins-linux-amd64-$cni_version.tgz" | sudo tar -C bin/cni -xz
fi

# manifests
echo Building k8s manifest files
manifest_files=(flannel.yaml kube-proxy.yaml)

for i in ${manifest_files[@]}; do
  resolve_and_save ../manifests/$i manifests/$i
done

# manifests
echo Building config files
config_files=(kubeconfig/admin.yaml kubeconfig/kubelet.yaml control-plane/kubelet-config.yaml control-plane/kube-proxy-config.yaml ssl/openssl.cnf flannel/cni-conf.json flannel/net-conf.json)

for i in ${config_files[@]}; do
  resolve_and_save ../config/$i config/$i
done

# systemd
echo Building systemd units
resolve_and_save ../systemd-units/kubelet.service systemd-units/kubelet.service

# generate certs
cd certs

# grab cert from master
echo downloading CA cert from $master_ip
scp $user@$master_ip:/etc/kubernetes/ssl/ca.pem ca.pem
scp $user@$master_ip:/etc/kubernetes/ssl/ca-key.pem ca-key.pem

# rest of the certs sign against CA
gen_cert admin kube-admin ../config/ssl/openssl.cnf
gen_cert kubelet "system:node:$host_name" ../config/ssl/openssl.cnf

chmod 644 *.pem
chown $user *.pem

cd $pwd_dir
