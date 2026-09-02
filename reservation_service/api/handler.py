"""Entrypoint HTTP da Lambda."""

from fastapi import FastAPI
from mangum import Mangum

app = FastAPI(title="Reservation Service", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}


handler = Mangum(app)

