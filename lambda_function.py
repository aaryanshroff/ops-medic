def lambda_handler(event, context):
    print("Event: ", event)
    
    return {"statusCode": 200, "body": "Hello from ops-medic!"}
