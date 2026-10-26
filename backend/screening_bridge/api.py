"""Authenticated single-host development API; public deployment defaults disabled.

SQLite claims prevent duplicate paid work across local workers. The public
milestone-2 deployment exposes health/catalog only; public live discovery needs
shared durable storage and anonymous-session controls in milestone 3.
"""

from contextlib import asynccontextmanager
import hashlib
import hmac
import json
import os
from pathlib import Path
import sqlite3
import time
from uuid import UUID

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import JSONResponse, StreamingResponse
import httpx

from .catalog import public_catalog
from .contract import DiscoveryRequest
from .discovery import DiscoveryService


def create_app(*, client: httpx.AsyncClient | None = None, qloo_key: str = "", openai_key: str = "", access_token: str = "", database: str = ".local/runs.sqlite", model: str = "gpt-5.4-mini") -> FastAPI:
    @asynccontextmanager
    async def lifespan(app):
        app.state.http = client or httpx.AsyncClient(timeout=30)
        yield
        if client is None:
            await app.state.http.aclose()

    app = FastAPI(title="Screening Bridge", lifespan=lifespan)
    configured = bool(qloo_key and openai_key and access_token) and not os.environ.get("VERCEL")

    def connection():
        Path(database).parent.mkdir(parents=True, exist_ok=True)
        db = sqlite3.connect(database, timeout=5)
        db.execute("CREATE TABLE IF NOT EXISTS runs (owner TEXT, id TEXT, fingerprint TEXT, state TEXT, events TEXT, created REAL, PRIMARY KEY(owner,id))")
        return db

    @app.middleware("http")
    async def limit_body(request: Request, call_next):
        if request.method == "POST" and len(await request.body()) > 32_000:
            return JSONResponse({"detail": "Screening brief is too large."}, status_code=413)
        return await call_next(request)

    @app.get("/health")
    async def health():
        return {"status": "ok", "schema_version": "1.0", "live_discovery_enabled": configured}

    @app.get("/v1/catalog")
    async def catalog():
        return public_catalog()

    @app.post("/v1/discoveries")
    async def discoveries(payload: DiscoveryRequest, request: Request):
        supplied = request.headers.get("Authorization", "")
        if not access_token or not hmac.compare_digest(supplied, "Bearer " + access_token):
            raise HTTPException(401, "Discovery access is required.")
        if not configured:
            raise HTTPException(503, "Live discovery is disabled on this deployment.")
        try:
            session_id = str(UUID(request.headers.get("X-Session-ID", "")))
        except ValueError:
            raise HTTPException(400, "A valid session ID is required.") from None
        owner = hashlib.sha256((access_token + session_id).encode()).hexdigest()
        fingerprint = hashlib.sha256(json.dumps(payload.model_dump(mode="json"), sort_keys=True).encode()).hexdigest()
        run_id = str(payload.request_id)
        with connection() as db:
            db.execute("BEGIN IMMEDIATE")
            row = db.execute("SELECT fingerprint,state,events FROM runs WHERE owner=? AND id=?", (owner, run_id)).fetchone()
            if row:
                if row[0] != fingerprint:
                    raise HTTPException(409, "This request ID belongs to a different brief.")
                if row[1] == "done":
                    return StreamingResponse(iter([row[2]]), media_type="text/event-stream", headers={"Cache-Control": "no-store"})
                raise HTTPException(409, "This request is running or was interrupted. Keep waiting, or explicitly start a new search.")
            if db.execute("SELECT count(*) FROM runs WHERE created>?", (time.time() - 86400,)).fetchone()[0] >= 50:
                raise HTTPException(429, "Today's development research limit has been reached.")
            if db.execute("SELECT count(*) FROM runs WHERE state='running' AND created>?", (time.time() - 120,)).fetchone()[0] >= 2:
                raise HTTPException(429, "Research is busy. Please try again shortly.")
            db.execute("INSERT INTO runs VALUES (?,?,?,?,?,?)", (owner, run_id, fingerprint, "running", "", time.time()))

        async def stream():
            events = []
            finished = False
            try:
                service = DiscoveryService(client=app.state.http, qloo_key=qloo_key, openai_key=openai_key, model=model)
                async for event in service.discover(payload):
                    if await request.is_disconnected():
                        break
                    encoded = "data: " + event.model_dump_json() + "\n\n"
                    events.append(encoded)
                    if event.type != "progress":
                        with connection() as db:
                            db.execute("UPDATE runs SET state='done',events=? WHERE owner=? AND id=?", ("".join(events), owner, run_id))
                        finished = True
                    yield encoded
            finally:
                if not finished:
                    with connection() as db:
                        db.execute("UPDATE runs SET state='interrupted' WHERE owner=? AND id=?", (owner, run_id))

        return StreamingResponse(stream(), media_type="text/event-stream", headers={"Cache-Control": "no-store", "X-Accel-Buffering": "no"})

    return app


app = create_app(qloo_key=os.environ.get("QLOO_API_KEY", ""), openai_key=os.environ.get("OPENAI_API_KEY", ""), access_token=os.environ.get("SCREENING_BRIDGE_TOKEN", ""), database=os.environ.get("SCREENING_BRIDGE_DATABASE", ".local/runs.sqlite"), model=os.environ.get("OPENAI_MODEL", "gpt-5.4-mini"))
