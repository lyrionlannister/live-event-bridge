import asyncio
import contextlib
from collections.abc import AsyncIterator

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI

from app.infrastructure.config.env import get_or_throw
from app.infrastructure.logging.logger import logger
from app.infrastructure.tiktok.tiktok_unofficial_adapter import TikTokUnofficialAdapter

_tiktok_task: asyncio.Task | None = None


async def _log_tiktok_events(stream_id: str) -> None:
    """Suscribe a TikTok LIVE y loggea cada evento recibido."""
    source = TikTokUnofficialAdapter()
    async for event in source.subscribe(stream_id):
        logger.info(
            "TikTok evento: tipo=%s sender=%s valor=%s",
            event.event_type,
            event.sender,
            event.value,
        )


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    global _tiktok_task

    tiktok_username = get_or_throw("TIKTOK_USERNAME")
    _tiktok_task = asyncio.create_task(_log_tiktok_events(tiktok_username))

    yield

    _tiktok_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await _tiktok_task


app = FastAPI(title="live-event-bridge", lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
