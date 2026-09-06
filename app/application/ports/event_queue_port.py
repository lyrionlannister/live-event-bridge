from abc import ABC, abstractmethod

from app.domain.live_event import LiveEvent


class EventQueuePort(ABC):
    """Cola intermedia entre la fuente del evento y su publicación al juego."""

    @abstractmethod
    async def enqueue(self, event: LiveEvent) -> None:
        raise NotImplementedError

    @abstractmethod
    async def dequeue(self) -> LiveEvent:
        raise NotImplementedError
