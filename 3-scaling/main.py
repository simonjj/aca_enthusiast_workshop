import os
from time import sleep
from azure.servicebus import ServiceBusClient, AutoLockRenewer
from azure.identity import DefaultAzureCredential


namespace = os.environ['SERVICE_BUS_NAMESPACE']
queue_name = os.environ['QUEUE_NAME']
credential = DefaultAzureCredential()


with ServiceBusClient(
    fully_qualified_namespace=namespace,
    credential=credential,
    logging_enable=True) as client:

    with client.get_queue_receiver(queue_name) as receiver:

            while True:

                # get a single message from the queue
                messages = receiver.receive_messages(max_message_count=1, max_wait_time=5)

                if not messages:
                    print("No messages received. Wait 10 seconds and try again.")
                    sleep(10)
                    continue

                message = messages[0]

                # process the message
                print("Received message: ", str(message))

                # complete the message
                receiver.complete_message(message)

                print("Message processed and completed.")
