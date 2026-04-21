# lambdas/processor/handler.py
import json
import os
import boto3
from urllib.parse import unquote_plus

### [module-level clients] ###
_s3       = boto3.client("s3")
_dynamodb = boto3.resource("dynamodb")

def handler(event, context):
    try:
        ### [parse s3 event] ###
        record     = event["Records"][0]
        bucket     = record["s3"]["bucket"]["name"]
        key        = unquote_plus(record["s3"]["object"]["key"])
        

        ### [read click json from s3] ###
        response   = _s3.get_object(Bucket=bucket, Key=key)
        click      = json.loads(response["Body"].read())
        short_code = click["short_code"]

        ### [increment count in dynamodb] ###
        table = _dynamodb.Table(os.environ["CLICK_COUNTS_TABLE"])
        table.update_item(
            Key={"short_code": short_code},
            UpdateExpression="ADD click_count :inc", # Atomic ADD operation
            ExpressionAttributeValues={":inc": 1},
        )

        print(f"OK: {short_code} count incremented")
        return {"statusCode": 200}

# Lambda retries on exceptions for async invocations (S3 triggers are)
# If we swallow the error and return 200, Lambda thinks it succeeded and won't retry
# Raising lets AWS retry the event automatically
    except Exception as exc:
        print(f"ERROR: {exc}")
        raise