import asyncio

from dotenv import load_dotenv

load_dotenv()

from app.application.use_cases.process_live_event import ProcessLiveEvent
from app.infrastructure.config.env import get_or_throw
from app.infrastructure.logging.logger import logger
from app.infrastructure.queue.redis_queue_adapter import RedisQueueAdapter
from app.infrastructure.roblox.roblox_open_cloud_adapter import RobloxOpenCloudAdapter
from app.infrastructure.tiktok.tiktok_unofficial_adapter import TikTokUnofficialAdapter


async def main() -> None:
    tiktok_username = get_or_throw("TIKTOK_USERNAME")
    roblox_api_key = get_or_throw("ROBLOX_API_KEY")
    roblox_universe_id = get_or_throw("ROBLOX_UNIVERSE_ID")
    roblox_topic = get_or_throw("ROBLOX_TOPIC")
    redis_url = get_or_throw("REDIS_URL")

    source = TikTokUnofficialAdapter()
    queue = RedisQueueAdapter(redis_url=redis_url)
    sink = RobloxOpenCloudAdapter(api_key=roblox_api_key, universe_id=roblox_universe_id)

    use_case = ProcessLiveEvent(
        source=source,
        queue=queue,
        sink=sink,
        topic=roblox_topic,
        stream_id=tiktok_username,
    )

    logger.info(
        "Iniciando live-event-bridge: %s -> topic '%s'", tiktok_username, roblox_topic
    )
    await use_case.run()


if __name__ == "__main__":
    asyncio.run(main())
