import json
import os
import time
import boto3
from urllib.parse import unquote_plus

### [module-level clients] ###
_s3       = boto3.client("s3")
_dynamodb = boto3.resource("dynamodb")

### [structured logging] ###
def log(level, **kwargs):
    print(json.dumps({"level": level, **kwargs}), flush=True)


def handler(event, context):
    start = time.monotonic()
    record     = event["Records"][0]
    bucket     = record["s3"]["bucket"]["name"]
    key        = unquote_plus(record["s3"]["object"]["key"])

    try:
        ### [read click json from s3] ###
        response   = _s3.get_object(Bucket=bucket, Key=key)
        click      = json.loads(response["Body"].read())
        short_code = click["short_code"]

        ### [increment count in dynamodb] ###
        table = _dynamodb.Table(os.environ["CLICK_COUNTS_TABLE"])
        table.update_item(
            Key={"short_code": short_code},
            UpdateExpression="ADD click_count :inc",
            ExpressionAttributeValues={":inc": 1},
        )

        log("INFO",
            short_code=short_code,
            s3_key=key,
            duration_ms=round((time.monotonic() - start) * 1000, 1),
        )
        return {"statusCode": 200}

    # Lambda retries on exception for async (S3-triggered) invocations —
    # raising lets AWS retry automatically instead of silently dropping the event
    except Exception as exc:
        log("ERROR",
            error=str(exc),
            s3_key=key,
            duration_ms=round((time.monotonic() - start) * 1000, 1),
        )
        raise
