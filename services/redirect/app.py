import json
import os
import time
import boto3
import psycopg2

from datetime import datetime, timezone
from fastapi import FastAPI, Request
from fastapi.responses import RedirectResponse, JSONResponse

app = FastAPI()

### [module-level cache] ###
_db_conn  = None
_db_creds = None
_s3       = boto3.client("s3")

### [structured logging] ###
def log(level, **kwargs):
    print(json.dumps({"level": level, **kwargs}), flush=True)


### [request timing middleware] ###
@app.middleware("http")
async def log_requests(request: Request, call_next):
    # health checks are high-volume and uninteresting — skip them
    if request.url.path == "/health":
        return await call_next(request)

    start    = time.monotonic()
    response = await call_next(request)
    duration = round((time.monotonic() - start) * 1000, 1)

    log("INFO",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=duration,
    )
    return response


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

def _write_click(bucket: str, code: str):
    key = f"clicks/{code}/{datetime.now(timezone.utc).isoformat()}.json"
    _s3.put_object(
        Bucket=bucket,
        Key=key,
        Body=json.dumps({"short_code": code, "timestamp": datetime.now(timezone.utc).isoformat()}),
        ContentType="application/json",
    )

### [routes] ###

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
            log("WARN", short_code=code, error="code not found")
            return JSONResponse(status_code=404, content={"error": "code not found"})

        _write_click(os.environ["CLICK_EVENTS_BUCKET"], code)

        log("INFO", short_code=code, destination=row[0], event="redirect")
        return RedirectResponse(url=row[0], status_code=302)

    except Exception as exc:
        log("ERROR", short_code=code, error=str(exc))
        return JSONResponse(status_code=500, content={"error": "internal error"})
