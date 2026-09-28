from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class LiveEvent:
    """Evento de una plataforma de streaming en vivo, ya normalizado.

    Entidad de dominio: sin dependencias de librerías externas.
    """

    platform: str
    event_type: str
    channel: str
    sender: str
    gift: str
    value: int | float
    raw_value: str
    timestamp: datetime
