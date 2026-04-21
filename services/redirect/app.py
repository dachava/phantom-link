# services/redirect/app.py
import json
import os
import boto3
import psycopg2

from datetime import datetime, timezone
from fastapi import FastAPI
from fastapi.responses import RedirectResponse, JSONResponse

app = FastAPI()

### [module-level cache] ###
_db_conn  = None
_db_creds = None

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

### [s3 client] ###
# boto3 clients are thread-safe and expensive to initialize
# one instance at module load time is fine, same caching pattern as Lambda
_s3 = boto3.client("s3")

# write to S3 before returning the redirect
# sync call for dev, async for prod
def _write_click(bucket: str, code: str):
    key = f"clicks/{code}/{datetime.now(timezone.utc).isoformat()}.json"
    _s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps({"short_code": code, "timestamp": datetime.now(timezone.utc).isoformat()}),
        ContentType="application/json",
    )

### [routes] ###

# The ALB health check hits this every 30 seconds 
# If it returns anything other than 2xx the task gets marked unhealthy and replaced
@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/{code}")
def redirect(code: str):
    try:
        conn = _get_conn()
        with conn.cursor() as cur:
            cur.execute(
                "SELECT long_url FROM url_mappings WHERE short_code = %s",
                (code,),
            )
            row = cur.fetchone()

        if not row:
            return JSONResponse(status_code=404, content={"error": "code not found"})

        _write_click(os.environ["CLICK_EVENTS_BUCKET"], code)

        return RedirectResponse(url=row[0], status_code=302)

    except Exception as exc:
        print(f"ERROR: {exc}")
        return JSONResponse(status_code=500, content={"error": "internal error"})