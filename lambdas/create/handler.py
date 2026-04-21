import json
import os
import secrets
import boto3
import psycopg2
from decimal import Decimal

### [module-level cache] ###
_db_conn   = None
_db_creds  = None
_dynamo    = boto3.resource("dynamodb")

CORS_HEADERS = {
    "Access-Control-Allow-Origin":  "*",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
}

def _get_creds():
    global _db_creds
    if _db_creds:
        return _db_creds
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    _db_creds = json.loads(secret["SecretString"])
    return _db_creds

def _get_conn():
    global _db_conn
    try:
        if _db_conn and not _db_conn.closed:
            return _db_conn
    except Exception:
        pass
    creds = _get_creds()
    _db_conn = psycopg2.connect(
        host=os.environ["DB_HOST"],
        port=5432,
        dbname=os.environ["DB_NAME"],
        user=creds["username"],
        password=creds["password"],
    )
    return _db_conn

def _ensure_table(conn):
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS url_mappings (
                short_code  VARCHAR(8)   PRIMARY KEY,
                long_url    TEXT         NOT NULL,
                created_at  TIMESTAMPTZ  DEFAULT NOW()
            )
        """)
    conn.commit()

### [route handlers] ###

def handle_create(event):
    body      = json.loads(event.get("body") or "{}")
    long_url  = body.get("url", "").strip()

    if not long_url:
        return _error(400, "url is required")

    short_code = secrets.token_urlsafe(6)[:8]
    base_url   = os.environ["BASE_URL"]

    conn = _get_conn()
    _ensure_table(conn)

    with conn.cursor() as cur:
        cur.execute(
            "INSERT INTO url_mappings (short_code, long_url) VALUES (%s, %s)",
            (short_code, long_url),
        )
    conn.commit()

    return _ok({"short_url": f"{base_url}/{short_code}"})


def handle_stats(event):
    short_code = (event.get("pathParameters") or {}).get("code", "").strip()

    if not short_code:
        return _error(400, "short_code is required")

    ### [postgres — url + created_at] ###
    conn = _get_conn()
    _ensure_table(conn)
    with conn.cursor() as cur:
        cur.execute(
            "SELECT long_url, created_at FROM url_mappings WHERE short_code = %s",
            (short_code,),
        )
        row = cur.fetchone()

    if not row:
        return _error(404, "short code not found")

    long_url, created_at = row

    ### [dynamodb — click count] ###
    table  = _dynamo.Table(os.environ["CLICK_COUNTS_TABLE"])
    result = table.get_item(Key={"short_code": short_code})
    click_count = int(result.get("Item", {}).get("click_count", 0))

    return _ok({
        "short_code":  short_code,
        "long_url":    long_url,
        "click_count": click_count,
        "created_at":  created_at.isoformat(),
    })


### [entry point] ###

def handler(event, context):
    method    = event.get("requestContext", {}).get("http", {}).get("method", "")
    route_key = event.get("routeKey", "")

    if method == "OPTIONS":
        return {"statusCode": 200, "headers": CORS_HEADERS, "body": ""}

    try:
        if route_key == "POST /create":
            return handle_create(event)
        if route_key == "GET /{code}/stats":
            return handle_stats(event)
        return _error(404, "not found")

    except Exception as exc:
        print(f"ERROR: {exc}")
        return _error(500, "internal error")


### [helpers] ###

def _ok(data):
    return {
        "statusCode": 200,
        "headers": {**CORS_HEADERS, "Content-Type": "application/json"},
        "body": json.dumps(data, default=str),
    }

def _error(status, message):
    return {
        "statusCode": status,
        "headers": {**CORS_HEADERS, "Content-Type": "application/json"},
        "body": json.dumps({"error": message}),
    }
