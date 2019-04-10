The test environment for [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)

# Preparation

1. Install Google Cloud SDK and initialize it - see [this](https://cloud.google.com/sdk/docs/quickstart-macos)
2. Create a service account for Terraform and generate an access key (json file) and download it
3. Set the env var like:
```
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/tf-wide-pulsar-217512-e560c3f528ec.json
export GCLOUD_PROJECT=wide-pulsar-217512
```
