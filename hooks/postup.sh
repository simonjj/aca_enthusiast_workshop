az account set -s $AZURE_SUBSCRIPTION_ID

az acr import --name $ACR_NAME --source docker.io/library/nginx:latest --image nginx:latest
