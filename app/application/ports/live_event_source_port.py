from collections.abc import AsyncIterator
from typing import Protocol

from app.domain.live_event import LiveEvent


class LiveEventSourcePort(Protocol):
    """Entrada: fuente de eventos de una plataforma de streaming en vivo."""

    async def subscribe(self, stream_id: str) -> AsyncIterator[LiveEvent]:
        ...
