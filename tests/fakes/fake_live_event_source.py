from collections.abc import AsyncIterator, Iterable

from app.domain.live_event import LiveEvent


class FakeLiveEventSource:
    """Fuente en memoria: emite una lista fija de eventos y termina."""

    def __init__(self, events: Iterable[LiveEvent]) -> None:
        self._events = list(events)
        self.subscribed_to: list[str] = []

    async def subscribe(self, stream_id: str) -> AsyncIterator[LiveEvent]:
        self.subscribed_to.append(stream_id)
        for event in self._events:
            yield event
