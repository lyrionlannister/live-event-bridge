from abc import ABC, abstractmethod

from app.domain.live_event import LiveEvent


class GameEventSinkPort(ABC):
    """Salida: destino del evento dentro del juego de Roblox."""

    @abstractmethod
    async def publish(self, event: LiveEvent) -> None:
        raise NotImplementedError
