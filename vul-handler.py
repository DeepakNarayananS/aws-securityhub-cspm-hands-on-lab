import json

# The lab intentionally pins an old dependency in requirements.txt so Amazon
# Inspector Lambda/code scanning has something realistic to evaluate.
import requests

def lambda_handler(event, context):
    r = requests.get("https://example.com", timeout=3)
    return {
        "statusCode": 200,
        "body": json.dumps({
            "lab": "securityhub-cspm",
            "requests_version": requests.__version__,
            "http_status": r.status_code
        })
    }
