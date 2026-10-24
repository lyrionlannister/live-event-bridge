from app.application.ports.logger_port import LoggerPort
from app.infrastructure.logging.logger import logger


class LoggerAdapter(LoggerPort):
    def debug(self, message: str, *args: object) -> None:
        logger.debug(message, *args)

    def info(self, message: str, *args: object) -> None:
        logger.info(message, *args)

    def warning(self, message: str, *args: object) -> None:
        logger.warning(message, *args)

    def exception(self, message: str, *args: object) -> None:
        logger.exception(message, *args)
