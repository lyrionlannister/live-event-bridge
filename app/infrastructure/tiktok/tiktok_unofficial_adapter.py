import asyncio
import contextlib
import logging
from collections.abc import AsyncIterator
from datetime import datetime, timezone

from TikTokLive import TikTokLiveClient
from TikTokLive.events import GiftEvent

from app.domain.live_event import LiveEvent

logger = logging.getLogger("live-event-bridge")

PLATFORM = "tiktok"
GIFT_EVENT_TYPE = "GIFT"

_INITIAL_BACKOFF_SECONDS = 1.0
_MAX_BACKOFF_SECONDS = 60.0


class TikTokUnofficialAdapter:
    """Fuente de eventos de TikTok LIVE vía la librería no oficial TikTokLive."""

    async def subscribe(self, stream_id: str) -> AsyncIterator[LiveEvent]:
        events: asyncio.Queue[LiveEvent] = asyncio.Queue()
        reconnect_task = asyncio.create_task(
            self._run_with_reconnect(stream_id, events)
        )

        try:
            while True:
                event = await events.get()
                yield event
        finally:
            reconnect_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await reconnect_task

    async def _run_with_reconnect(
        self, stream_id: str, events: "asyncio.Queue[LiveEvent]"
    ) -> None:
        backoff = _INITIAL_BACKOFF_SECONDS

        while True:
            client = TikTokLiveClient(unique_id=stream_id)

            @client.on(GiftEvent)
            async def _on_gift(event: GiftEvent) -> None:
                if event.value is None:
                    return  # regalo en medio de un streak, aún no es el conteo final

                await events.put(self._to_live_event(event))

            try:
                logger.info("Conectando a TikTok LIVE de %s", stream_id)
                await client.connect()
                logger.warning("Desconectado de TikTok LIVE de %s", stream_id)
                backoff = _INITIAL_BACKOFF_SECONDS
            except Exception:
                logger.exception("Error conectando a TikTok LIVE de %s", stream_id)

            logger.info("Reintentando conexión a TikTok en %.1fs", backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, _MAX_BACKOFF_SECONDS)

    @staticmethod
    def _to_live_event(event: GiftEvent) -> LiveEvent:
        sender = "desconocido"
        if event.user is not None:
            sender = event.user.unique_id or event.user.nickname or sender

        diamond_count = event.gift.diamond_count if event.gift is not None else 0

        return LiveEvent(
            platform=PLATFORM,
            event_type=GIFT_EVENT_TYPE,
            sender=sender,
            value=event.value or 0,
            raw_value=str(diamond_count),
            timestamp=datetime.now(timezone.utc),
        )
