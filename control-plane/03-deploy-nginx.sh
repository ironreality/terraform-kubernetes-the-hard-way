#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo
echo "Installing Nginx..."

for instance in controller-0 controller-1 controller-2; do
  echo
  echo "Installing Nginx to: ${instance}..."
  gcloud compute ssh ${instance} -- sudo apt-get install -y nginx || { echo "Can't install Nginx! Exiting..."; exit 1; }

  echo "Generating Nginx config..."
cat > kubernetes.default.svc.cluster.local<<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

  gcloud compute scp kubernetes.default.svc.cluster.local ${instance}:~/ || { echo "Can't copy the files to ${instance}! Exiting..."; exit 1; }
  gcloud compute ssh ${instance} -- sudo cp kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/ || { echo "Can't copy the etcd's binaries to /usr/local/bin! Exiting..."; exit 1; } 

  echo
  echo "Enabling & starting Nginx..."
  gcloud compute ssh ${instance} -- sudo systemctl restart nginx || { echo "Can't restart Nginx! Exiting..."; exit 1; } 
  gcloud compute ssh ${instance} -- sudo systemctl enable nginx || { echo "Can't enable Nginx! Exiting..."; exit 1; } 

  echo "TEST: Checking the k8s healthcheck page..."
  gcloud compute ssh ${instance} -- 'wget --quiet --server-response --header "Host: kubernetes.default.svc.cluster.local" http://127.0.0.1/healthz'
done
