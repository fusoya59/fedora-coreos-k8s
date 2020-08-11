#!/bin/sh
fcc_file_url=https://someurl.com/ignition.fcc
curl -O $fcc_file_url
podman run -i --rm quay.io/coreos/fcct:release --pretty --strict < ignition.fcc > ignition.ign
coreos-installer install /dev/sda --copy-network --ignition-file ignition.ign