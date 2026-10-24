import asyncio
import json
import logging

import httpx

logger = logging.getLogger("live-event-bridge")

# Endpoint confirmado en
# https://create.roblox.com/docs/cloud/reference/features/universes.md
# POST /cloud/v2/universes/{universe_id}:publishMessage
# body: {"topic": str, "message": str}
_ROBLOX_BASE_URL = "https://apis.roblox.com"

_MAX_ATTEMPTS = 3
_INITIAL_BACKOFF_SECONDS = 2.0


class RobloxOpenCloudAdapter:
    """Publica eventos a un juego de Roblox vía Open Cloud Messaging Service."""

    def __init__(self, api_key: str, universe_id: str) -> None:
        self._api_key = api_key
        self._universe_id = universe_id

    async def publish(self, topic: str, payload: dict) -> None:
        url = f"{_ROBLOX_BASE_URL}/cloud/v2/universes/{self._universe_id}:publishMessage"
        headers = {"x-api-key": self._api_key, "Content-Type": "application/json"}
        body = {"topic": topic, "message": json.dumps(payload)}

        backoff = _INITIAL_BACKOFF_SECONDS

        async with httpx.AsyncClient(timeout=10.0) as client:
            for attempt in range(1, _MAX_ATTEMPTS + 1):
                response = await client.post(url, headers=headers, json=body)

                if response.status_code == 429:
                    logger.warning(
                        "Rate limit de Roblox Open Cloud (intento %s/%s), "
                        "esperando %.1fs antes de reintentar",
                        attempt,
                        _MAX_ATTEMPTS,
                        backoff,
                    )
                    await asyncio.sleep(backoff)
                    backoff *= 2
                    continue

                response.raise_for_status()
                return

        raise RuntimeError(
            f"No se pudo publicar en el topic '{topic}': rate limit persistente "
            f"tras {_MAX_ATTEMPTS} intentos"
        )
