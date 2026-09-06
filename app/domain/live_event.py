from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class LiveEvent:
    """Evento de una plataforma de streaming en vivo, ya normalizado.

    Entidad de dominio: sin dependencias de librerías externas.
    """

    platform: str
    event_type: str
    sender: str
    value_normalized: int
    timestamp: datetime
