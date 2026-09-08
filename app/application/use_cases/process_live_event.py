import asyncio
import logging

from app.application.ports.event_queue_port import EventQueuePort
from app.application.ports.game_event_sink_port import GameEventSinkPort
from app.application.ports.live_event_source_port import LiveEventSourcePort
from app.domain.live_event import LiveEvent

logger = logging.getLogger("live-event-bridge")

GIFT_EVENT_TYPE = "GIFT"


class ProcessLiveEvent:
    """Orquesta el flujo: consume -> filtra GIFT -> encola -> desencola -> publica."""

    def __init__(
        self,
        source: LiveEventSourcePort,
        queue: EventQueuePort,
        sink: GameEventSinkPort,
        topic: str,
        stream_id: str,
    ) -> None:
        self._source = source
        self._queue = queue
        self._sink = sink
        self._topic = topic
        self._stream_id = stream_id

    async def run(self) -> None:
        """Corre productor y consumidor de forma concurrente hasta que se cancele."""
        await asyncio.gather(self._produce(), self._consume())

    async def _produce(self) -> None:
        async for event in self._source.subscribe(self._stream_id):
            logger.info(
                "Evento recibido: plataforma=%s tipo=%s sender=%s",
                event.platform,
                event.event_type,
                event.sender,
            )

            if event.event_type != GIFT_EVENT_TYPE:
                continue

            await self._queue.enqueue(event)
            logger.info(
                "Evento encolado: sender=%s valor=%s", event.sender, event.value
            )

    async def _consume(self) -> None:
        async for event in self._queue.dequeue():
            try:
                await self._sink.publish(self._topic, self._to_payload(event))
                logger.info(
                    "Evento publicado: sender=%s topic=%s", event.sender, self._topic
                )
            except Exception:
                logger.exception(
                    "Fallo al publicar evento de %s, se continúa procesando",
                    event.sender,
                )

    @staticmethod
    def _to_payload(event: LiveEvent) -> dict:
        return {
            "platform": event.platform,
            "event_type": event.event_type,
            "sender": event.sender,
            "value": event.value,
            "raw_value": event.raw_value,
            "timestamp": event.timestamp.isoformat(),
        }
