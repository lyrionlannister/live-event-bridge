import asyncio
from collections.abc import AsyncIterator

from app.domain.live_event import LiveEvent


class FakeEventQueue:
    """Cola en memoria respaldada por asyncio.Queue (bloquea igual que Redis BRPOP)."""

    def __init__(self) -> None:
        self._queue: asyncio.Queue[LiveEvent] = asyncio.Queue()
        self.enqueued: list[LiveEvent] = []

    async def enqueue(self, event: LiveEvent) -> None:
        self.enqueued.append(event)
        await self._queue.put(event)

    async def dequeue(self) -> AsyncIterator[LiveEvent]:
        while True:
            event = await self._queue.get()
            yield event
