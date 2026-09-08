import asyncio
import contextlib
import logging
from collections.abc import AsyncIterator
from datetime import datetime, timezone

from TikTokLive import TikTokLiveClient
from TikTokLive.client.errors import SignatureRateLimitError, UserOfflineError
from TikTokLive.events import (
    CommentEvent,
    ConnectEvent,
    FollowEvent,
    GiftEvent,
    JoinEvent,
    LikeEvent,
    ShareEvent,
    SocialEvent,
)
from websockets.legacy.exceptions import InvalidStatusCode

from app.domain.live_event import LiveEvent

logger = logging.getLogger("live-event-bridge")

PLATFORM = "tiktok"
GIFT_EVENT_TYPE = "GIFT"

_INITIAL_BACKOFF_SECONDS = 1.0
_MAX_BACKOFF_SECONDS = 60.0
_OFFLINE_BACKOFF_SECONDS = 30.0

# Bugs de schema de protobuf upstream (TikTokLive/betterproto2) que no podemos
# arreglar acá; se degradan a DEBUG en vez de ensuciar los logs con ERROR.
_KNOWN_PARSE_ERROR_FINGERPRINTS = [
    "HashtagNamespace",  # WebcastLinkLayerMessage, no usado por este MVP
]


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
            client.parse_error_ignorelist.extend(_KNOWN_PARSE_ERROR_FINGERPRINTS)

            @client.on(ConnectEvent)
            async def _on_connect(event: ConnectEvent) -> None:
                logger.info(
                    "Conectado a TikTok LIVE de %s (room_id=%s)",
                    stream_id,
                    event.room_id,
                )

            @client.on(GiftEvent)
            async def _on_gift(event: GiftEvent) -> None:
                if event.value is None:
                    return  # regalo en medio de un streak, aún no es el conteo final

                await events.put(self._to_live_event(event))

            @client.on(CommentEvent)
            async def _on_comment(event: CommentEvent) -> None:
                logger.info(
                    "TikTok comentario: sender=%s texto=%r",
                    self._sender_name(event.user),
                    event.content,
                )

            @client.on(LikeEvent)
            async def _on_like(event: LikeEvent) -> None:
                logger.info(
                    "TikTok like: sender=%s count=%s total=%s",
                    self._sender_name(event.user),
                    event.count,
                    event.total,
                )

            @client.on(JoinEvent)
            async def _on_join(event: JoinEvent) -> None:
                logger.info(
                    "TikTok usuario entró al stream: sender=%s",
                    self._sender_name(event.user),
                )

            @client.on(FollowEvent)
            async def _on_follow(event: FollowEvent) -> None:
                logger.info(
                    "TikTok nuevo follow: sender=%s",
                    self._sender_name(event.user),
                )

            @client.on(ShareEvent)
            async def _on_share(event: ShareEvent) -> None:
                logger.info(
                    "TikTok share: sender=%s",
                    self._sender_name(event.user),
                )

            @client.on(SocialEvent)
            async def _on_social(event: SocialEvent) -> None:
                logger.info(
                    "TikTok evento social: sender=%s action=%s",
                    self._sender_name(event.user),
                    event.action,
                )

            try:
                logger.info("Conectando a TikTok LIVE de %s", stream_id)
                await client.connect()
                logger.warning("Desconectado de TikTok LIVE de %s", stream_id)
                backoff = _INITIAL_BACKOFF_SECONDS
            except UserOfflineError:
                logger.info("%s no está en vivo todavía", stream_id)
                backoff = max(backoff, _OFFLINE_BACKOFF_SECONDS)
            except SignatureRateLimitError as error:
                backoff = max(backoff, error.retry_after or _OFFLINE_BACKOFF_SECONDS)
                logger.warning(
                    "Sign server de TikTok rate-limited para %s, esperando %.1fs",
                    stream_id,
                    backoff,
                )
            except InvalidStatusCode as error:
                logger.warning(
                    "TikTok rechazó la conexión de %s (HTTP %s), probablemente "
                    "un rechazo transitorio del servidor; reintentando",
                    stream_id,
                    error.status_code,
                )
            except Exception:
                logger.exception("Error conectando a TikTok LIVE de %s", stream_id)

            logger.info("Reintentando conexión a TikTok en %.1fs", backoff)
            await asyncio.sleep(backoff)
            backoff = min(backoff * 2, _MAX_BACKOFF_SECONDS)

    @staticmethod
    def _sender_name(user: object) -> str:
        if user is None:
            return "desconocido"
        return getattr(user, "unique_id", None) or getattr(user, "nickname", None) or "desconocido"

    @classmethod
    def _to_live_event(cls, event: GiftEvent) -> LiveEvent:
        diamond_count = event.gift.diamond_count if event.gift is not None else 0

        return LiveEvent(
            platform=PLATFORM,
            event_type=GIFT_EVENT_TYPE,
            sender=cls._sender_name(event.user),
            value=event.value or 0,
            raw_value=str(diamond_count),
            timestamp=datetime.now(timezone.utc),
        )
