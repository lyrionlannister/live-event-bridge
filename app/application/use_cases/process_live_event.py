import asyncio
import logging

from app.application.ports.event_queue_port import EventQueuePort
from app.application.ports.game_event_sink_port import GameEventSinkPort
from app.application.ports.live_event_source_port import LiveEventSourcePort
from app.domain.live_event import LiveEvent

logger = logging.getLogger("live-event-bridge")

GIFT_EVENT_TYPE = "GIFT"
SCHEMA_VERSION = 1


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
        """Corre productor y consumidor de forma concurrente hasta que se cancele.

        Si uno de los dos muere por una excepción, se cancela el otro y se
        relanza el error, en vez de dejarlo corriendo huérfano en silencio
        (ej. si Redis no está listo todavía cuando arranca el consumidor).
        """
        tasks = [asyncio.create_task(self._produce()), asyncio.create_task(self._consume())]
        try:
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_EXCEPTION)
            for task in pending:
                task.cancel()
            for task in done:
                task.result()
        except asyncio.CancelledError:
            for task in tasks:
                task.cancel()
            raise

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
        """Arma el mensaje según roblox-sdk/contract/schema-v1.md."""
        return {
            "v": SCHEMA_VERSION,
            "type": "gift",
            "platform": event.platform,
            "channel": event.channel,
            "sender": event.sender,
            "gift": event.gift,
            "value": event.value,
            "ts": round(event.timestamp.timestamp() * 1000),
        }
