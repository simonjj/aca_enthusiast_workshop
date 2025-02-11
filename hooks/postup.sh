#!/bin/bash
set -e

az account set -s $AZURE_SUBSCRIPTION_ID


if [ "$(az acr repository show -n $ACR_NAME --repository nginx -o tsv)" ]; then
    echo "Image already exists in ACR"
else
    az acr import --name $ACR_NAME --source docker.io/library/nginx:latest --image nginx:latest
fi

if [ "$(az acr repository show -n $ACR_NAME --repository service-bus-consumer -o tsv)" ]; then
    echo "Image already exists in ACR"
else
    az acr build --registry $ACR_NAME --image service-bus-consumer:latest 3-scaling
fi

az containerapp update -n $APP3_NAME -g $AZURE_RESOURCE_GROUP --image $ACR_NAME.azurecr.io/service-bus-consumer:latest
