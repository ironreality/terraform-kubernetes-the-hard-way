#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

if [[ -z ${ENCRYPTION_KEY} ]]; then
  echo "Can't generate the encryption key! Exiting..."; exit 1;
fi

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

echo "Copying the encryption key to the master nodes..."
for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done
