#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

k8s_version="1.12.0"

echo
echo "Creating k8s-related directories and systemd unit files..."
for instance in controller-0 controller-1 controller-2; do
  echo
  echo "Processing node: ${instance}"

  echo
  echo "Creating k8s-related directories..."
  gcloud compute ssh ${instance} -- sudo mkdir -p /etc/kubernetes/config /var/lib/kubernetes/ \
    || { echo "Can't create the directories! Exiting..."; exit 1; }

  echo
  echo "Copying the TLS certs to /var/lib/kubernetes..."
  gcloud compute ssh ${instance} -- sudo cp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
		service-account-key.pem service-account.pem \
		encryption-config.yaml /var/lib/kubernetes/ \
	|| { echo "Can't copy the tls certs! Exiting..."; exit 1; }

  INTERNAL_IP=$(gcloud compute ssh ${instance} -- curl -s -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
  if [[ -z ${INTERNAL_IP} ]]; then
    echo "Can't get the internal IP for ${instance}! Exiting..."; exit 1;
  fi

### kube-apiserver
  echo
  echo "Configureing kube-apiserver..."
  echo "Generationg kube-apiserver's systemd unit file for node: ${instance}..."
  cat >kube-apiserver.service<<EOF
  [Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo
  echo "Copying the kube-apiserver's unit file to ${instance}..."
  gcloud compute scp  kube-apiserver.service ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kube-apiserver.service /etc/systemd/system/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

  echo
  echo "Enabling kube-apiserver systemd service..."
  gcloud compute ssh ${instance} -- sudo systemctl daemon-reload || { echo "Can't reload systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl enable kube-apiserver || { echo "Can't enable systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl restart kube-apiserver || { echo "Can't start etcd! Exiting..."; exit 1; }

### kube-controller-manager
  echo
  echo "Configureing kube-controller-manager..."
  echo "Generationg kube-controller-manager's systemd unit file for node: ${instance}..."
  cat >kube-controller-manager.service<<EOF
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo
  echo "Copying the kube-controller-manager's unit file to ${instance}..."
  gcloud compute scp kube-controller-manager.service ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kube-controller-manager.service /etc/systemd/system/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

	echo
	echo "Copying kube-controller-manager.kubeconfig to /var/lib/kubernetes..."
  gcloud compute ssh ${instance} -- sudo cp kube-controller-manager.kubeconfig /var/lib/kubernetes/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

  echo
  echo "Enabling kube-controller-manager systemd service..."
  gcloud compute ssh ${instance} -- sudo systemctl daemon-reload || { echo "Can't reload systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl enable kube-controller-manager || { echo "Can't enable systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl restart kube-controller-manager || { echo "Can't start etcd! Exiting..."; exit 1; }

### kube-scheduler
  echo
  echo "Configureing kube-scheduler..."
  echo "Generationg kube-scheduler's systemd unit file for node: ${instance}..."
  cat >kube-scheduler.service<<EOF
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
    --v=2
    Restart=on-failure
    RestartSec=5

    [Install]
    WantedBy=multi-user.target
EOF

  echo
  echo "Copying the kube-scheduler's unit file to ${instance}..."
  gcloud compute scp kube-scheduler.service ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kube-scheduler.service /etc/systemd/system/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

	echo
	echo "Copying kube-scheduler.kubeconfig to /var/lib/kubernetes..."
  gcloud compute ssh ${instance} -- sudo cp kube-scheduler.kubeconfig /var/lib/kubernetes/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

  echo "Generating kube-scheduler.yaml config..."
  cat >kube-scheduler.yaml<<EOF
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

  echo
  echo "Copying the kube-scheduler.yaml unit file to ${instance}..."
  gcloud compute scp kube-scheduler.yaml ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kube-scheduler.yaml /etc/kubernetes/config/ || { echo "Can't copy the files! Exiting..."; exit 1; }

  echo
  echo "Enabling kube-scheduler systemd service..."
  gcloud compute ssh ${instance} -- sudo systemctl daemon-reload || { echo "Can't reload systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl enable kube-scheduler || { echo "Can't enable systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl restart kube-scheduler || { echo "Can't start etcd! Exiting..."; exit 1; }

done
