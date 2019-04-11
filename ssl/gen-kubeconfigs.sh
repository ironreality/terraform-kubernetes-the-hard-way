#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way --region $(gcloud config get-value compute/region) --format 'value(address)')

if [[ -z ${KUBERNETES_PUBLIC_ADDRESS} ]]; then
  echo "Can't determine the Kubernetes public IP! Exiting..."; exit 1;
fi

echo
echo "Generating the kubelets' kubeconfigs..."

for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

echo "TEST: checking the kubelet's kubeconfigs presence..."
[[ -f worker-0.kubeconfig ]] || exit 1
[[ -f worker-1.kubeconfig ]] || exit 1
[[ -f worker-2.kubeconfig ]] || exit 1

echo
echo "Generating the kube-proxy's kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

echo "TEST: check the kube-proxy's kubeconfig presence..."
[[ -f kube-proxy.kubeconfig ]] || exit 1

echo
echo "Generating the kube-controller-manager's kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig

echo "TEST: checking the kube-controller-manager's kubeconfig presence..."
[[ -f kube-controller-manager.kubeconfig ]] || exit 1

echo
echo "Generating the kube-scheduler kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig

echo "TEST: checking the kube-scheduler's kubeconfig presence..."
[[ -f kube-scheduler.kubeconfig ]] || exit 1

echo
echo "Generating the admin's kubeconfig..."
kubectl config set-cluster kubernetes-the-hard-way \
        --certificate-authority=ca.pem \
            --embed-certs=true \
                --server=https://127.0.0.1:6443 \
                    --kubeconfig=admin.kubeconfig

kubectl config set-credentials admin \
          --client-certificate=admin.pem \
              --client-key=admin-key.pem \
                  --embed-certs=true \
                      --kubeconfig=admin.kubeconfig

kubectl config set-context default \
            --cluster=kubernetes-the-hard-way \
                --user=admin \
                    --kubeconfig=admin.kubeconfig

kubectl config use-context default --kubeconfig=admin.kubeconfig

echo "TEST: checking the admin's kubeconfig presence..."
[[ -f admin.kubeconfig ]] || exit 1
