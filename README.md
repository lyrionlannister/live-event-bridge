# live-event-bridge

Puente en tiempo real entre **TikTok LIVE** y **Roblox**: escucha los regalos de una transmisión, los encola en **Redis** y los publica en un juego de Roblox mediante **Roblox Open Cloud Messaging**, donde un SDK en Luau los decodifica y dispara acciones dentro del juego.

## Arquitectura

Arquitectura hexagonal (puertos y adaptadores), para poder cambiar la fuente de eventos o el destino sin tocar la lógica:

```
TikTok LIVE ──► TikTokUnofficialAdapter ──► ProcessLiveEvent ──► RedisQueueAdapter ──► RobloxOpenCloudAdapter ──► Roblox (Luau SDK)
                 (LiveEventSourcePort)       (caso de uso)        (EventQueuePort)        (GameEventSinkPort)
```

| Capa | Contenido |
| --- | --- |
| `app/domain` | Modelo `LiveEvent` |
| `app/application` | Puertos y caso de uso `ProcessLiveEvent` |
| `app/infrastructure` | Adaptadores de TikTok, Redis, Roblox, configuración y logging |
| `app/interfaces/api` | App FastAPI que arranca el pipeline en su ciclo de vida |
| `roblox-sdk` | Contrato del mensaje (`schema-v1`) y decodificador en Luau |

## Stack

Python 3.14 · FastAPI · Redis · httpx · Pydantic · TikTokLive · Luau · Docker Compose · pytest · uv

## Cómo correrlo

```bash
cp .env.example .env   # TIKTOK_USERNAME, ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_TOPIC
docker compose up --build
```

Sin Docker:

```bash
uv sync
uv run fastapi run app/interfaces/api/main.py
```

## Pruebas

```bash
uv run pytest
```

Las pruebas usan fakes de los puertos; las marcadas como `integration` requieren credenciales reales y no corren por defecto.

## Licencia

Ver [LICENSE](LICENSE).
