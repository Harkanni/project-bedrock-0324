import json
import logging
import urllib.parse

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def handler(event, context):
    """
    Triggered by S3 ObjectCreated events on the bedrock-assets bucket.
    Exam spec (4.5) only requires logging the uploaded filename to
    CloudWatch Logs — kept deliberately simple, no image manipulation.
    """
    for record in event.get("Records", []):
        bucket = record["s3"]["bucket"]["name"]
        # S3 event keys are URL-encoded (e.g. spaces become '+')
        key = urllib.parse.unquote_plus(record["s3"]["object"]["key"])
        logger.info("Image received: %s", key)
        print(f"Image received: {key}")

    return {
        "statusCode": 200,
        "body": json.dumps({"processed": len(event.get("Records", []))}),
    }