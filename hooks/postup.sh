#!/bin/bash
set -e

az account set -s $AZURE_SUBSCRIPTION_ID


if [ "$(az acr repository show -n $ACR_NAME --repository nginx -o tsv)" ]; then
    echo "Image already exists in ACR"
else
    az acr import --name $ACR_NAME --source docker.io/library/nginx:latest --image nginx:latest
fi
