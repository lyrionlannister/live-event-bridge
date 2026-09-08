class FakeGameEventSink:
    """Sink en memoria que registra publicaciones y puede simular fallos."""

    def __init__(self, fail_times: int = 0) -> None:
        self._fail_times = fail_times
        self.published: list[tuple[str, dict]] = []

    async def publish(self, topic: str, payload: dict) -> None:
        if self._fail_times > 0:
            self._fail_times -= 1
            raise RuntimeError("fallo simulado del sink")

        self.published.append((topic, payload))
