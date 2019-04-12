#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Downloading etcd..."
[[ -f etcd-v3.3.9-linux-amd64.tar.gz ]] || wget -q --show-progress --https-only --timestamping "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz" || { echo "Can't download etcd binary! Exiting..."; exit 1; }

echo
echo "Extracting etcd from the archive..."
tar -xf etcd-v3.3.9-linux-amd64.tar.gz || { echo "Can't extract the etcd archive! Exiting..."; exit 1; }

echo
echo "Copying the etcd binaries to the cluster master nodes..."
for instance in controller-0 controller-1 controller-2; do
  echo
  echo "Copying files to: ${instance}..."
  gcloud compute scp --recurse etcd-v3.3.9-linux-amd64/etcd* ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp etcd etcdctl /usr/local/bin/ || { echo "Can't copy the etcd's binaries to /usr/local/bin! Exiting..."; exit 1; }
done

echo
echo "Creating etcd directories and systemd unit files..."
for instance in controller-0 controller-1 controller-2; do
  echo
  echo "Processing node: ${instance}"

  echo
  echo "Creating etcd-related directories..."
  gcloud compute ssh ${instance} -- sudo mkdir -p /etc/etcd /var/lib/etcd || { echo "Can't create the directories! Exiting..."; exit 1; }

  echo
  echo "Copying the TLS certs to /etc/etcd..."
  gcloud compute ssh ${instance} -- sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/ || { echo "Can't copy the tls certs to /etc/etcd! Exiting..."; exit 1; }

  INTERNAL_IP=$(gcloud compute ssh ${instance} -- curl -s -H "Metadata-Flavor:Google" http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)
  if [[ -z ${INTERNAL_IP} ]]; then
    echo "Can't get the internal IP for ${instance}! Exiting..."; exit 1;
  fi

  ETCD_NAME=$(gcloud compute ssh ${instance} -- hostname -s)
  if [[ -z ${ETCD_NAME} ]]; then
    echo "Can't get the hostname ${instance}! Exiting..."; exit 1;
  fi

  echo
  echo "Generationg etcd's sysmted unit file for node: ${instance}..."
  cat >etcd.service<<EOF
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

  echo
  echo "Copying the etcd's unit file to ${instance}..."
  gcloud compute scp etcd.service ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp etcd.service /etc/systemd/system/ || { echo "Can't copy the files to /etc/systemd! Exiting..."; exit 1; }

  echo
  echo "Enabling etcd systemd service..."
  gcloud compute ssh ${instance} -- sudo systemctl daemon-reload || { echo "Can't reload systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl enable etcd || { echo "Can't enable systemd! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo systemctl restart etcd || { echo "Can't start etcd! Exiting..."; exit 1; }
done

echo
echo "TEST: checking the etcd cluster..."
gcloud compute ssh controller-0 -- sudo ETCDCTL_API=3 etcdctl member list --endpoints=https://127.0.0.1:2379 --cacert=/etc/etcd/ca.pem --cert=/etc/etcd/kubernetes.pem --key=/etc/etcd/kubernetes-key.pem || { echo "Can't connect the etcd! Exiting..."; exit 1; }
