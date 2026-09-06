"""
Sistema de logging con rotación diaria y organización mensual de archivos.
"""

import logging
import os

from datetime import datetime
from app.infrastructure.settings.env import get_or_throw


class MonthlyDailyRotatingFileHandler(logging.Handler):
    """
    Handler que crea un archivo de log por día y organiza los archivos
    dentro de carpetas mensuales.

    Estructura:

        logs/
        ├── 2026-09/
        │   ├── 2026-09-04.log
        │   ├── 2026-09-05.log
        │   └── ...
        └── 2026-10/
            └── ...
    """

    def __init__(
        self,
        base_dir: str = "./logs",
        encoding: str = "utf-8",
    ):
        super().__init__()

        self.base_dir = base_dir
        self.encoding = encoding

        self._current_date: str | None = None
        self._file_handler: logging.FileHandler | None = None

        os.makedirs(self.base_dir, exist_ok=True)

        self._update_handler()

    def _get_current_date(self) -> str:
        return datetime.now().strftime("%Y-%m-%d")

    def _get_log_path(self) -> str:
        now = datetime.now()

        month_folder = os.path.join(
            self.base_dir,
            now.strftime("%Y-%m"),
        )

        os.makedirs(month_folder, exist_ok=True)

        return os.path.join(
            month_folder,
            f"{now.strftime('%Y-%m-%d')}.log",
        )

    def _update_handler(self) -> None:
        current_date = self._get_current_date()

        if current_date == self._current_date:
            return

        if self._file_handler is not None:
            self._file_handler.close()

        self._file_handler = logging.FileHandler(
            self._get_log_path(),
            encoding=self.encoding,
        )

        self._file_handler.setFormatter(self.formatter)

        self._current_date = current_date

    def emit(self, record: logging.LogRecord) -> None:
        try:
            self._update_handler()

            if self._file_handler is not None:
                self._file_handler.emit(record)

        except Exception:
            self.handleError(record)

    def close(self) -> None:
        if self._file_handler is not None:
            self._file_handler.close()
            self._file_handler = None

        super().close()


class Logger:
    """
    Singleton para el manejo centralizado del logging de la aplicación.
    """

    _instance = None
    _initialized = False

    _ENVIROMENT = get_or_throw("ENV")

    def __new__(cls, *args, **kwargs):
        if cls._instance is None:
            cls._instance = super().__new__(cls)

        return cls._instance

    def __init__(self):
        if self._initialized:
            return

        self._initialized = True

        self.logger = logging.getLogger("live-event-bridge")

        self.logger.propagate = False

        self.logger.setLevel(
            logging.DEBUG
            if self._ENVIROMENT == "development"
            else logging.INFO
        )

        formatter = logging.Formatter(
            "%(asctime)s - %(levelname)s - %(message)s",
            "%Y-%m-%d %H:%M:%S",
        )

        if self._ENVIROMENT == "development":
            handler = logging.StreamHandler()

        else:
            handler = MonthlyDailyRotatingFileHandler(
                base_dir="./logs",
                encoding="utf-8",
            )

        handler.setLevel(
            logging.DEBUG
            if self._ENVIROMENT == "development"
            else logging.INFO
        )

        handler.setFormatter(formatter)

        self.logger.addHandler(handler)

    def get_logger(self) -> logging.Logger:
        return self.logger