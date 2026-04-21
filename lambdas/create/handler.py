# lambdas/create/handler.py
import json
import os
import secrets
import boto3
import psycopg2

### [module-level cache] ###
# These live outside the handler so they survive across warm invocations...
# warm calls skip the Secrets Manager API call and skip reconnecting to Postgres entirely
# Without this, every request pays a ~100ms penalty
# On cold start they're None; on the first real call populate them once
_db_conn = None
_db_creds = None

def _get_creds():
    """Pull DB credentials from Secrets Manager. Cached after first call."""
    global _db_creds
    if _db_creds:
        return _db_creds
    client = boto3.client("secretsmanager")
    secret = client.get_secret_value(SecretId=os.environ["DB_SECRET_ARN"])
    _db_creds = json.loads(secret["SecretString"])
    return _db_creds
    # the handler never has a credential in its source code, they come from Terraform

def _get_conn():
    """Return a live psycopg2 connection. Reconnects if the connection dropped."""
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
    # Idempotent
    """Create url_mappings if it doesn't exist yet. Safe to call every cold start."""
    with conn.cursor() as cur:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS url_mappings (
                short_code  VARCHAR(8)   PRIMARY KEY,
                long_url    TEXT         NOT NULL,
                created_at  TIMESTAMPTZ  DEFAULT NOW()
            )
        """)
    conn.commit()

### [handler] ###
def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
        long_url = body.get("url", "").strip()
        if not long_url:
            return {"statusCode": 400, "body": json.dumps({"error": "url is required"})}

        short_code = secrets.token_urlsafe(6)[:8]   # 8 URL-safe chars
        base_url   = os.environ["BASE_URL"]          # e.g. https://phantom.link

        conn = _get_conn()
        _ensure_table(conn)

        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO url_mappings (short_code, long_url) VALUES (%s, %s)",
                (short_code, long_url),
            )
        conn.commit()

        return {
            "statusCode": 200,
            "body": json.dumps({"short_url": f"{base_url}/{short_code}"}),
        }

    except Exception as exc:
        # Don't leak internals... log and return a generic 500
        print(f"ERROR: {exc}")
        return {"statusCode": 500, "body": json.dumps({"error": "internal error"})}