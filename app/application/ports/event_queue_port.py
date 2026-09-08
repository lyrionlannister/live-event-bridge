from collections.abc import AsyncIterator
from typing import Protocol

from app.domain.live_event import LiveEvent


class EventQueuePort(Protocol):
    """Cola intermedia entre la fuente del evento y su publicación al juego."""

    async def enqueue(self, event: LiveEvent) -> None:
        ...

    async def dequeue(self) -> AsyncIterator[LiveEvent]:
        ...
