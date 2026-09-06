from abc import ABC, abstractmethod


class LoggerPort(ABC):
    """Logging visto desde application

    application no puede importar app.infrastructure.logging.logger
    directo.
    """

    @abstractmethod
    def debug(self, message: str, *args: object) -> None:
        raise NotImplementedError

    @abstractmethod
    def info(self, message: str, *args: object) -> None:
        raise NotImplementedError

    @abstractmethod
    def warning(self, message: str, *args: object) -> None:
        raise NotImplementedError

    @abstractmethod
    def exception(self, message: str, *args: object) -> None:
        """Loggea el error actual (dentro de un except) con traceback."""
        raise NotImplementedError
