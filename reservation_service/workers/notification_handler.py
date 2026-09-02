"""Entrypoint do consumidor de notificações."""

from typing import Any


def handler(event: dict[str, Any], context: Any) -> dict[str, int]:
    del event, context
    return {"processed": 0}

