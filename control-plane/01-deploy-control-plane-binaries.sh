#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

k8s_version="1.12.0"

echo "Downloading the Kubernetes binaries..."

download_binary() {
  binary=$1
  [[ -f ${binary} ]] || \
    echo && \
    echo "Downloading ${binary}..." && \
    wget -q --show-progress --https-only --timestamping \
    "https://storage.googleapis.com/kubernetes-release/release/v${k8s_version}/bin/linux/amd64/${binary}" || { echo "Can't download ${binary}! Exiting..."; exit 1; }
    chmod +x ${binary}
}

download_binary kube-apiserver
download_binary kube-controller-manager
download_binary kube-scheduler
download_binary kubectl

echo
echo "Copying the kontrol plane binaries to the cluster master nodes..."
for instance in controller-0 controller-1 controller-2; do
  echo
  echo "Copying files to: ${instance}..."
  gcloud compute scp kube-apiserver kube-controller-manager kube-scheduler kubectl ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/ || { echo "Can't copy the etcd's binaries to /usr/local/bin! Exiting..."; exit 1; }
done
