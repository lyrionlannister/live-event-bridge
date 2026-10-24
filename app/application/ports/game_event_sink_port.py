from typing import Protocol


class GameEventSinkPort(Protocol):
    """Salida: destino del evento dentro del juego de Roblox."""

    async def publish(self, topic: str, payload: dict) -> None:
        ...
