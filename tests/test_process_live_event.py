import asyncio
import contextlib
from collections.abc import Callable
from datetime import datetime, timezone

from app.application.use_cases.process_live_event import ProcessLiveEvent
from app.domain.live_event import LiveEvent
from tests.fakes.fake_event_queue import FakeEventQueue
from tests.fakes.fake_game_event_sink import FakeGameEventSink
from tests.fakes.fake_live_event_source import FakeLiveEventSource


def _make_event(
    event_type: str = "GIFT",
    sender: str = "user1",
    value: int = 10,
    channel: str = "canal_demo",
    gift: str = "Rose",
) -> LiveEvent:
    return LiveEvent(
        platform="tiktok",
        event_type=event_type,
        channel=channel,
        sender=sender,
        gift=gift,
        value=value,
        raw_value=str(value),
        timestamp=datetime.now(timezone.utc),
    )


async def _wait_until(condition: Callable[[], bool], timeout: float = 1.0) -> None:
    elapsed = 0.0
    interval = 0.01
    while not condition():
        if elapsed >= timeout:
            raise AssertionError("timeout esperando la condición")
        await asyncio.sleep(interval)
        elapsed += interval


async def _run_briefly(use_case: ProcessLiveEvent, timeout: float = 0.2) -> None:
    """Corre run() (que nunca termina solo) por un instante y lo cancela."""
    task = asyncio.create_task(use_case.run())
    await asyncio.sleep(timeout)
    task.cancel()
    with contextlib.suppress(asyncio.CancelledError):
        await task


async def _run_until_and_stop(
    use_case: ProcessLiveEvent, condition: Callable[[], bool], timeout: float = 1.0
) -> None:
    task = asyncio.create_task(use_case.run())
    try:
        await _wait_until(condition, timeout=timeout)
    finally:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task


async def test_evento_gift_se_publica_correctamente():
    source = FakeLiveEventSource(
        [_make_event(event_type="GIFT", sender="ana", value=50, channel="ana_live", gift="Rose")]
    )
    queue = FakeEventQueue()
    sink = FakeGameEventSink()
    use_case = ProcessLiveEvent(source, queue, sink, topic="mi-topic", stream_id="ana_live")

    await _run_until_and_stop(use_case, lambda: len(sink.published) == 1)

    topic, payload = sink.published[0]
    assert topic == "mi-topic"
    assert payload["v"] == 1
    assert payload["type"] == "gift"
    assert payload["platform"] == "tiktok"
    assert payload["channel"] == "ana_live"
    assert payload["sender"] == "ana"
    assert payload["gift"] == "Rose"
    assert payload["value"] == 50
    assert isinstance(payload["ts"], int)


async def test_evento_no_gift_se_ignora():
    source = FakeLiveEventSource([_make_event(event_type="LIKE", sender="ana")])
    queue = FakeEventQueue()
    sink = FakeGameEventSink()
    use_case = ProcessLiveEvent(source, queue, sink, topic="mi-topic", stream_id="ana_live")

    await _run_briefly(use_case)

    assert sink.published == []
    assert queue.enqueued == []


async def test_falla_del_sink_no_tumba_el_loop_completo():
    events = [
        _make_event(event_type="GIFT", sender="ana", value=10),
        _make_event(event_type="GIFT", sender="beto", value=20),
    ]
    source = FakeLiveEventSource(events)
    queue = FakeEventQueue()
    sink = FakeGameEventSink(fail_times=1)  # el primer publish falla
    use_case = ProcessLiveEvent(source, queue, sink, topic="mi-topic", stream_id="ana_live")

    await _run_until_and_stop(use_case, lambda: len(sink.published) == 1)

    topic, payload = sink.published[0]
    assert payload["sender"] == "beto"
