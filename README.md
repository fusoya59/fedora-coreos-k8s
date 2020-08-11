# fedora-coreos-k8s
Build a k8s cluster on Fedora CoreOS.

# Installation

## Bootstrap Fedora CoreOS
This is an example. You do not need to follow the exact steps.

1. Edit /bootstrap-example/ignition-master.fcc and fill in `{SOME_HOST_NAME}` and `{SOME_SSH_KEY}`.
2. Upload this file to some publicly available URL.
3. Fill in variable `fcc_file_url` in bootstrap.sh.
4. Run `sudo ./bootstrap.sh` on Fedora CoreOS live CD.

## Build for master node
Once you're logged in to your server, clone this repo:
```
$ git clone https://github.com/fusoya59/fedora-coreos-k8s
```

Build the project:
```
$ cd fedora-coreos-k8s
$ sudo ./build-master.sh fusoya59
```

## Deploy master node
Deploy the files:
```
$ sudo ./deploy-master.sh fusoya59
```

Wait a minute or two for the entire process to bootstrap properly. After that
install kubectl:
```
$ ./setup-kubectl.sh
```
Try getting the nodes in the cluster:
```
$ kubectl get nodes
```

## Build for master node
Same steps. Clone repo:
```
$ git clone https://github.com/fusoya59/fedora-coreos-k8s
```

Build the project:
```
$ cd fedora-coreos-k8s
$ sudo ./build-worker.sh fusoya59 10.0.10.100
```

## Deploy worker node
Deploy the files:
```
$ sudo ./deploy-worker.sh fusoya59 10.0.10.100
```

Log back into master. Check that the node was added:
```
$ kubectl get nodes
```