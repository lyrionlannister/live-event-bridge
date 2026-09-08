import json
from collections.abc import AsyncIterator
from datetime import datetime

import redis.asyncio as redis

from app.domain.live_event import LiveEvent

_BRPOP_TIMEOUT_SECONDS = 5
_DEFAULT_QUEUE_KEY = "live-event-bridge:events"


class RedisQueueAdapter:
    """Cola de eventos respaldada por una lista de Redis (LPUSH/BRPOP)."""

    def __init__(self, redis_url: str, queue_key: str = _DEFAULT_QUEUE_KEY) -> None:
        self._client = redis.from_url(redis_url)
        self._queue_key = queue_key

    async def enqueue(self, event: LiveEvent) -> None:
        await self._client.lpush(self._queue_key, self._serialize(event))

    async def dequeue(self) -> AsyncIterator[LiveEvent]:
        while True:
            result = await self._client.brpop(self._queue_key, timeout=_BRPOP_TIMEOUT_SECONDS)
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
                "sender": event.sender,
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
            sender=data["sender"],
            value=data["value"],
            raw_value=data["raw_value"],
            timestamp=datetime.fromisoformat(data["timestamp"]),
        )
