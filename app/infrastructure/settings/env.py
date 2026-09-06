import os


def get_or_throw(key: str) -> str:
    value = os.environ.get(key)
    if not value:
        raise RuntimeError(
            f"Falta la variable de entorno {key}. Debe estar definida en .env.app."
        )
    return value

def get_or_default(key: str, default: str) -> str:
    value = os.environ.get(key)
    if not value:
        return default
    return value
