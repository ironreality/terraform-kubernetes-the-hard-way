#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo
echo "Generating api to kubelet RBAC..."

cat > kube-apiserver-to-kubelet.yaml<<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF

echo
echo "Copying the RBAC config to controller-0..."
gcloud compute scp kube-apiserver-to-kubelet.yaml controller-0:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }

echo
echo "Applying the RBAC config..."
gcloud compute ssh controller-0 -- sudo kubectl apply --kubeconfig admin.kubeconfig -f kube-apiserver-to-kubelet.yaml || { echo "Can't create the RBAC policy! Exiting..."; exit 1; }
