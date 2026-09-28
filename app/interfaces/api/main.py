import asyncio
import contextlib
from collections.abc import AsyncGenerator

from dotenv import load_dotenv

load_dotenv()

from fastapi import FastAPI

from app.application.use_cases.process_live_event import ProcessLiveEvent
from app.infrastructure.config.env import get_or_default, get_or_throw
from app.infrastructure.logging.logger import logger
from app.infrastructure.queue.redis_queue_adapter import RedisQueueAdapter
from app.infrastructure.roblox.roblox_open_cloud_adapter import RobloxOpenCloudAdapter
from app.infrastructure.tiktok.tiktok_unofficial_adapter import TikTokUnofficialAdapter

_process_task: asyncio.Task | None = None


def _log_if_failed(task: asyncio.Task) -> None:
    if task.cancelled():
        return
    exc = task.exception()
    if exc is not None:
        logger.error("El pipeline de eventos murió inesperadamente", exc_info=exc)


@contextlib.asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None]:
    global _process_task

    tiktok_username = get_or_throw("TIKTOK_USERNAME")
    redis_url = get_or_throw("REDIS_URL")
    roblox_api_key = get_or_throw("ROBLOX_API_KEY")
    roblox_universe_id = get_or_throw("ROBLOX_UNIVERSE_ID")
    roblox_topic = get_or_default("ROBLOX_TOPIC", "live-events")

    use_case = ProcessLiveEvent(
        source=TikTokUnofficialAdapter(),
        queue=RedisQueueAdapter(redis_url),
        sink=RobloxOpenCloudAdapter(api_key=roblox_api_key, universe_id=roblox_universe_id),
        topic=roblox_topic,
        stream_id=tiktok_username,
    )
    _process_task = asyncio.create_task(use_case.run())
    _process_task.add_done_callback(_log_if_failed)
    logger.info("live-event-bridge iniciado: escuchando TikTok LIVE de %s", tiktok_username)

    yield

    _process_task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await _process_task
    logger.info("live-event-bridge detenido")


app = FastAPI(title="live-event-bridge", lifespan=lifespan)


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
