from abc import ABC, abstractmethod
from collections.abc import Awaitable, Callable

from app.domain.live_event import LiveEvent


class LiveEventSourcePort(ABC):
    """Entrada: fuente de eventos de una plataforma de streaming en vivo."""

    @abstractmethod
    async def start(
        self, on_event: Callable[[LiveEvent], Awaitable[None]]
    ) -> None:
        """Empieza a escuchar eventos y los entrega vía on_event."""
        raise NotImplementedError

    @abstractmethod
    async def stop(self) -> None:
        raise NotImplementedError
