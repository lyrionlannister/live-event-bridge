from TikTokLive.client.web.web_settings import WebDefaults

from app.infrastructure.config.env import get_or_throw

PLATFORM = "tiktok"
GIFT_EVENT_TYPE = "GIFT"

INITIAL_BACKOFF_SECONDS = 1.0
MAX_BACKOFF_SECONDS = 60.0
OFFLINE_BACKOFF_SECONDS = 30.0

# Bugs de schema de protobuf upstream (TikTokLive/betterproto2) que no podemos
# arreglar acá; se degradan a DEBUG en vez de ensuciar los logs con ERROR.
KNOWN_PARSE_ERROR_FINGERPRINTS = [
    "HashtagNamespace",  # WebcastLinkLayerMessage, no usado por este MVP
]


def configure_sign_api_key() -> None:
    """Registra la API key del sign server (Euler Stream) para TikTokLive."""
    WebDefaults.tiktok_sign_api_key = get_or_throw("TIKTOK_CLIENT_KEY")
