#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Copying the kubelet's and kube-proxy kubeconfigs..."
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done

echo "Copying the controler-manager & scheduler configs..."
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done
