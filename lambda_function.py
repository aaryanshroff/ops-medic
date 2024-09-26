import requests

def lambda_handler(event, context):
    print("Event: ", event)
    
    # Extract logs_url from the event
    try:
        logs_url = event['workflow_run']['logs_url']
        print("Logs URL: ", logs_url)
    except KeyError as e:
        print(f"Key error: {e}")
        return {"statusCode": 400, "body": "Invalid event structure"}

    # Make a call to get the logs
    try:
        response = requests.get(logs_url)
        response.raise_for_status()
        logs = response.text
        print("Logs: ", logs)
    except requests.exceptions.RequestException as e:
        print(f"Request error: {e}")
        return {"statusCode": 500, "body": "Failed to retrieve logs"}

    return {"statusCode": 200, "body": "Logs retrieved successfully"}