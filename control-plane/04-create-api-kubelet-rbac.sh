#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo
echo "Generating api to kubelet RBAC configs..."

echo
echo "Generating api to kubelet cluster role..."
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

echo "Generating api to kubelet cluster role binding..."
cat > kube-apiserver-to-kubelet-binding.yaml<<EOF
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

echo
echo "Copying the RBAC config to controller-0..."
gcloud compute scp kube-apiserver-to-kubelet.yaml kube-apiserver-to-kubelet-binding.yaml controller-0:~/ || { echo "Can't copy the files to controller-0! Exiting..."; exit 1; }

echo
echo "Creating the cluster role..."
gcloud compute ssh controller-0 -- sudo kubectl apply --kubeconfig admin.kubeconfig -f kube-apiserver-to-kubelet.yaml || { echo "Can't create the cluster role! Exiting..."; exit 1; }

echo
echo "Creating the cluster role binding..."
gcloud compute ssh controller-0 -- sudo kubectl apply --kubeconfig admin.kubeconfig -f kube-apiserver-to-kubelet-binding.yaml || { echo "Can't create the cluster role binding! Exiting..."; exit 1; }
