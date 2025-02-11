# Azure Container Apps scale configuration example: Azure Service Bus job

Before you begin, make sure you create an Azure Container Apps environment and a container registry by following the instructions on the main [README](../../README.md).

## Overview

The example job is in [main.py](main.py). It processes a single message from the queue and exits. The job is triggered by a message in the queue using the scale rule you define below.

## Deployment

1. For simplicity, you'll name the Azure Service Bus namespace the same as the Azure Container Registry:

    ```bash
    export SERVICE_BUS_NAMESPACE=$ACR_NAME
    ```

1. Set other variables:

    ```bash
    export QUEUE_NAME=job-queue
    export JOB_NAME=azure-servicebus-job
    ```

1. Create a new Azure Service Bus namespace:

    ```bash
    az servicebus namespace create --name $SERVICE_BUS_NAMESPACE --resource-group $RESOURCE_GROUP_NAME \
        --location $LOCATION
    ```

1. Create a new Azure Service Bus queue:

    ```bash
    az servicebus queue create --name $QUEUE_NAME --namespace-name $SERVICE_BUS_NAMESPACE \
        --resource-group $RESOURCE_GROUP_NAME --lock-duration PT1M
    ```

    The `--lock-duration` parameter specifies the duration for which the message is locked for other receivers. The default value is 1 minute. If your job takes longer than 1 minute to process a message, you must set up a lock renewer to keep the lock alive.

1. Get the connection string for the Azure Service Bus namespace:

    ```bash
    export SERVICE_BUS_CONNECTION_STRING=$(az servicebus namespace authorization-rule keys list --name RootManageSharedAccessKey --namespace-name $SERVICE_BUS_NAMESPACE --resource-group $RESOURCE_GROUP_NAME --query primaryConnectionString -o tsv)
    ```

1. Ensure your current working directory is same directory containing this README file. Run the following command to build the container image and push it to the Azure Container Registry:

    ```bash
    az acr build --registry $ACR_NAME --image azure-servicebus-job:1.0 .
    ```

1. Create a new Azure Container Apps job:

    ```bash
    az containerapp job create --name $JOB_NAME --environment $ENVIRONMENT_NAME \
        --resource-group $RESOURCE_GROUP_NAME --image $ACR_NAME.azurecr.io/azure-servicebus-job:1.0 \
        --registry-server $ACR_NAME.azurecr.io \
        --trigger-type Event \
        --min-executions 0 --max-executions 10 \
        --secrets "connection-string-secret=$SERVICE_BUS_CONNECTION_STRING" \
        --env-vars "SERVICE_BUS_CONNECTION_STRING=secretref:connection-string-secret" "QUEUE_NAME=$QUEUE_NAME" \
        --scale-rule-name service-bus \
        --scale-rule-type azure-servicebus \
        --scale-rule-metadata "queueName=$QUEUE_NAME" "messageCount=1" \
        --scale-rule-auth "connection=connection-string-secret"
    ```

    The command specifies the image to deploy. By including `--registry-server`, the command automatically configures the job to authenticate with the Azure Container Registry. The remaining parameters are described below.

1. Send a message to the queue to trigger the job:
    - Go to the Azure portal and open the Azure Service Bus namespace you created.
    - In the left-hand menu, select **Queues**.
    - Select the queue you created.
    - In the queue details, select **Service Bus Explorer**.
    - In the Service Bus Explorer, select **Send Messages**.
    - In the **Message Body** field, enter a message and select **Send**.

1. Monitor the job's execution:
    - Go to the Container Apps job in the Azure portal.
    - In the left-hand menu, select **Execution History**.
    - You should see a new execution for the job.

## Details

There are two pieces to any event-driven job in Azure Container Apps: the job and the scale rule. They must be configured so that the scale rule monitors the same queue that the job executions process messages from. In the above configuration, the scale rule uses the same configuration values as the job's environment variables.

### Job

The job performs these steps:
1. Receives a message from the queue (locking the message for processing).
1. Processes the message.
1. Completes the message (removing it from the queue).
1. Exits.

> Note that it's important to complete the message only after the job execution has finished processing it. If the job fails, the message will be unlocked and another job execution can process it. In long running jobs, waiting until the job has finished processing the message before completing will ensure scaling is more accurate.

The job is configured with the following environment variables that it needs to run:

- `SERVICE_BUS_CONNECTION_STRING`: The connection string for the Azure Service Bus namespace, stored in a secret.
- `QUEUE_NAME`: The name of the queue to monitor.

These match the scale rule configuration.

### Scale rule

Because the job processes a single message per execution, the scale rule must be configured to run an execution for every message in the queue. The scale rule follows the [KEDA Service Bus scaler specification](
https://keda.sh/docs/scalers/azure-service-bus/) and is configured with the following settings:

- `trigger-type`: The type of trigger for the job. For event-driven jobs, it's `Event`.
- `scale-rule-name`: The name of the scale rule.
- `scale-rule-type`: The type of the scale rule. In this example, it's `azure-servicebus`.
- `scale-rule-metadata`: The metadata for the scale rule.
    - `queueName`: The name of the queue to monitor.
    - `messageCount`: The number of messages to process per job execution. In this example, the job processes a single message per execution so we set it to 1.
- `scale-rule-auth`: The authentication for the scale rule. These are properties that reference secrets in the app.
    - `connection`: The name of the secret containing the connection string for the Azure Service Bus namespace.
- `min-executions`: The minimum number of executions to run per polling interval. In this example, it's set to 0.
- `max-executions`: The maximum number of executions to run per polling interval. In this example, it's set to 10.

By default, the scale rule polls the queue's metadata every 30 seconds. In each polling interval, the scale rule gets the number of messages in the queue and divides it by `messageCount`. It then runs a number of executions equal to the result, up to `max-executions`. If there are no messages in the queue, it runs `min-executions` executions.

If there are on-going executions when the scale rule polls the queue, the number of running executions counts towards the `max-executions` limit. This means it calculates the number of new executions to start based on this formula:

```
new_executions = max(max_executions - (queue_message_count / messageCount) - running_executions, min_executions)
```

### More information

#### Multiple messages per execution

Sometimes it's more efficient to process multiple messages per execution. To do this, you can change the `messageCount` in the scale rule configuration to a higher number. The job must be modified to process the number of messages specified in the scale rule configuration.

#### Change the number of concurrent executions

You can change the `max-executions` in the scale rule configuration to control the number of concurrent executions.

#### Advanced job and scaler configuration

For more advanced job and scale rule configuration, see the [Azure Container Apps documentation](https://learn.microsoft.com/en-us/azure/container-apps/jobs?tabs=azure-cli#advanced-job-configuration).

For longer running jobs, increase the `replica-timeout`.

Other settings such as `polling-interval`, `parallelism`, and `replica-completion-count` are advanced settings and should be used with caution.

#### Lock renewer

If your job takes longer than the lock duration to process a message, you must set up a lock renewer to keep the lock alive. The lock renewer is a separate thread that runs alongside the job and renews the lock on the message at regular intervals. This ensures the message is not unlocked while the job is processing it. See [main.py](main.py) for an example of how to implement a lock renewer in Python.

#### Topics and subscriptions

If you use topics and subscriptions in your Azure Service Bus, you can configure the scale rule to monitor a subscription instead of a queue. Instead of configuring the `queueName` in the scale rule, you configure the `subscriptionName` and `topicName`. The job must be modified to process messages from the subscription instead of the queue.

#### Shared access key or shared access signature

Container Apps supports both shared access key and shared access signature (SAS) authentication for Azure Service Bus. You can scope the shared access key to the specific queue or topic you want to monitor. The shared access policy must have the `Manage` permission on the queue or topic. See the [KEDA Service Bus scaler specification](https://keda.sh/docs/scalers/azure-service-bus/) for more information.

Container Apps doesn't yet support managed identity for scale rules.

