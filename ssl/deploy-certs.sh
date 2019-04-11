#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Copying the certifitates and keys to the worker instances..."
for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done

echo "Copying the certifitates and keys to the master instances..."
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done
