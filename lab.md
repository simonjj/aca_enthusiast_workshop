# Hands on lab

## Initial deployment

1. Ensure you are using a posix shell (bash, zsh, etc. in Linux, macOS, or WSL). You can also using Cloud Shell in the Azure Portal.

1. Ensure you have Azure CLI and Azure Developer CLI (AzD) installed and you are logged in to both tools.

1. Use AzD to deploy the lab resources:

    ```bash
    git clone https://github.com/simonjj/aca_enthusiast_workshop
    azd auth login
    az login
    azd up
    ```
    When prompted:
    - Provide an environment name
    - Select the subscription you want to deploy to
    - Create a new resource group

## Labs


### 1. Managed identity

In the `1-image-pull` directory, you will find a simple ACA app that pulls an image from Azure Container Registry (ACR). The app is configured to use its system-assigned managed identity to authenticate with ACR. You can try deploying it to the lab ACA environment:

```bash
az deployment group create -f 1-image-pull/app1.bicep -g $RESOURCE_GROUP_NAME
```

However, you'll notice it fails (if it results in a deployment that runs forever, delete the app before proceeding). Fix the Bicep file and try again.


### 2. Health Probes

In the Azure portal and the resource group you've created, find the `sickly-app`. It won't start. Try and get the application to start.


### 3. Scaling

In the Azure portal, browse to the resource group you deployed to in this lab. Find the app named `app3`. This app processes messages from a Service Bus queue and has a scale rule configured to scale based on the number of messages in the queue.

Click on the `Scale` blade and notice that the app is configured to scale to 0 when there are no messages in the queue, but it's scaled to 1. And if you add messages to the Service Bus queue, the app doesn't scale out to process them.

Figure out them problem and fix it.


### 4. Networking

#### Request timeout

In the portal and the created resource group navigate to `request-delay-app` to retrieve it's URL. Append the following request details: `/long-request?delay=50` to form a URL that looks as follows: `https://yourcluster-name.location.containerapps.io/long-request?delay=50`. For delay try `3`, `30` and `250` and see what happens.

#### Private App + Private Link + Front Door

Find the `quickstart-behind-afd` app. It has been deployed inside a private environment and should not be reachable from the outside except through Azure Front Door. Finish the configuration, there's one last step remaining. Then test the setup end-to-end by accessing the application through its AFD URL the hostname should have the following format `afd-techconnecUNIQ1-UNIQ2.b01.azurefd.net`. Hint: The final step to activate this configuration can be found here: [final steps](https://github.com/microsoft/azure-container-apps/tree/main/templates/bicep/privateEndpointFrontDoor#approving-the-connection)

#### URL Filtering

Find the `request-logger-app` and observe the filtering ACA performs on incoming URL. For example try accessing the following `https://request-logger-app.cluster-name.location.azurecontainerapps.io/something/redirect/http%3A%2F%2Fschema.org%2Fresources%2F123`. Compare the input URL with what the request logger shows under `url`.
