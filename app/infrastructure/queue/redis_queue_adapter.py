import asyncio
import json
import logging
from collections.abc import AsyncIterator
from datetime import datetime

import redis.asyncio as redis

from app.domain.live_event import LiveEvent

logger = logging.getLogger("live-event-bridge")

_BRPOP_TIMEOUT_SECONDS = 5
_DEFAULT_QUEUE_KEY = "live-event-bridge:events"
_RECONNECT_BACKOFF_SECONDS = 2.0

# El socket_timeout del cliente debe ser mayor que el timeout de bloqueo de
# BRPOP: si no, el cliente puede cortar la lectura por su cuenta justo antes
# de que Redis responda con su propio timeout, lanzando un TimeoutError
# espurio en una espera completamente normal de cola vacía.
_SOCKET_TIMEOUT_SECONDS = _BRPOP_TIMEOUT_SECONDS + 10


class RedisQueueAdapter:
    """Cola de eventos respaldada por una lista de Redis (LPUSH/BRPOP)."""

    def __init__(self, redis_url: str, queue_key: str = _DEFAULT_QUEUE_KEY) -> None:
        self._client = redis.from_url(redis_url, socket_timeout=_SOCKET_TIMEOUT_SECONDS)
        self._queue_key = queue_key

    async def enqueue(self, event: LiveEvent) -> None:
        await self._client.lpush(self._queue_key, self._serialize(event))

    async def dequeue(self) -> AsyncIterator[LiveEvent]:
        while True:
            try:
                result = await self._client.brpop(self._queue_key, timeout=_BRPOP_TIMEOUT_SECONDS)
            except redis.RedisError:
                logger.warning(
                    "Redis no respondió esperando eventos, reintentando en %.1fs",
                    _RECONNECT_BACKOFF_SECONDS,
                )
                await asyncio.sleep(_RECONNECT_BACKOFF_SECONDS)
                continue

            if result is None:
                continue  # timeout de BRPOP sin datos, se sigue esperando

            _, raw = result
            yield self._deserialize(raw)

    @staticmethod
    def _serialize(event: LiveEvent) -> str:
        return json.dumps(
            {
                "platform": event.platform,
                "event_type": event.event_type,
                "channel": event.channel,
                "sender": event.sender,
                "gift": event.gift,
                "value": event.value,
                "raw_value": event.raw_value,
                "timestamp": event.timestamp.isoformat(),
            }
        )

    @staticmethod
    def _deserialize(raw: bytes | str) -> LiveEvent:
        data = json.loads(raw)
        return LiveEvent(
            platform=data["platform"],
            event_type=data["event_type"],
            channel=data["channel"],
            sender=data["sender"],
            gift=data["gift"],
            value=data["value"],
            raw_value=data["raw_value"],
            timestamp=datetime.fromisoformat(data["timestamp"]),
        )
