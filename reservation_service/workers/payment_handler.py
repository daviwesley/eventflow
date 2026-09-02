"""Entrypoint do consumidor de pagamentos."""

from typing import Any


def handler(event: dict[str, Any], context: Any) -> dict[str, int]:
    """Processa mensagens SQS de pagamento; implementação será adicionada depois."""
    del event, context
    return {"processed": 0}

