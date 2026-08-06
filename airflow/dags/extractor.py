"""
extractor.py — забирает данные из OpenF1 API.
"""

import logging
import time
from typing import Any

import requests


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
)

logger = logging.getLogger(__name__)

BASE_URL = "https://api.openf1.org/v1"

MAX_RETRIES = 3
REQUEST_TIMEOUT_SECONDS = 30
SUCCESS_REQUEST_DELAY_SECONDS = 3.0


def fetch(
    endpoint: str,
    params: dict[str, Any] | None = None,
    allow_not_found: bool = False,
) -> list[dict[str, Any]]:
    """
    Выполняет запрос к OpenF1 API.

    Использует:
    - повторные попытки при сетевых и HTTP-ошибках;
    - увеличенную задержку при ответе 429 Too Many Requests;
    - экспоненциальную задержку при остальных ошибках;
    - паузу после успешного запроса;
    - возможность считать 404 допустимым отсутствием данных.
    """
    url = f"{BASE_URL}/{endpoint}"

    for attempt in range(MAX_RETRIES):
        try:
            response = requests.get(
                url,
                params=params,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )

            response.raise_for_status()

            data = response.json()

            if not isinstance(data, list):
                raise RuntimeError(
                    f"GET /{endpoint} вернул неожиданный тип данных: "
                    f"{type(data).__name__}"
                )

            logger.info(
                "GET /%s → %s записей, параметры: %s",
                endpoint,
                len(data),
                params,
            )

            # Пауза между успешными запросами снижает риск ответа 429.
            time.sleep(SUCCESS_REQUEST_DELAY_SECONDS)

            return data

        except requests.exceptions.HTTPError as error:
            status_code = (
                error.response.status_code
                if error.response is not None
                else None
            )

            # Для некоторых сессий данных по пит-стопам может не быть.
            # В этом случае 404 считаем допустимым результатом.
            if status_code == 404 and allow_not_found:
                logger.info(
                    "GET /%s → данных нет, параметры: %s",
                    endpoint,
                    params,
                )
                return []

            if status_code == 429:
                retry_delay = 15 * (attempt + 1)
            else:
                retry_delay = 2**attempt

            logger.warning(
                "Попытка %s/%s для GET /%s не удалась. "
                "HTTP-статус: %s. Ошибка: %s. "
                "Повтор через %s сек.",
                attempt + 1,
                MAX_RETRIES,
                endpoint,
                status_code,
                error,
                retry_delay,
            )

            if attempt < MAX_RETRIES - 1:
                time.sleep(retry_delay)

        except requests.exceptions.RequestException as error:
            retry_delay = 2**attempt

            logger.warning(
                "Попытка %s/%s для GET /%s не удалась: %s. "
                "Повтор через %s сек.",
                attempt + 1,
                MAX_RETRIES,
                endpoint,
                error,
                retry_delay,
            )

            if attempt < MAX_RETRIES - 1:
                time.sleep(retry_delay)

        except ValueError as error:
            raise RuntimeError(
                f"Не удалось преобразовать ответ GET /{endpoint} в JSON. "
                f"Параметры: {params}"
            ) from error

    raise RuntimeError(
        f"Не удалось получить данные из GET /{endpoint} "
        f"после {MAX_RETRIES} попыток. Параметры: {params}"
    )


def get_sessions(year: int) -> list[dict[str, Any]]:
    """Возвращает все сессии за указанный год."""
    return fetch("sessions", {"year": year})


def get_drivers(session_key: int) -> list[dict[str, Any]]:
    """
    Возвращает пилотов конкретной сессии.

    Для отдельных сессий OpenF1 может не содержать данные о пилотах.
    В таком случае возвращается пустой список.
    """
    return fetch(
        "drivers",
        {"session_key": session_key},
        allow_not_found=True,
    )


def get_laps(session_key: int) -> list[dict[str, Any]]:
    """
    Возвращает данные о кругах конкретной сессии.

    Для отдельных сессий OpenF1 может не содержать данные о кругах.
    В таком случае возвращается пустой список.
    """
    return fetch(
        "laps",
        {"session_key": session_key},
        allow_not_found=True,
    )


def get_pit_stops(session_key: int) -> list[dict[str, Any]]:
    """
    Возвращает данные о пит-стопах конкретной сессии.

    Для сессий без пит-стопов OpenF1 может вернуть 404.
    В таком случае возвращается пустой список.
    """
    return fetch(
        "pit",
        {"session_key": session_key},
        allow_not_found=True,
    )


def get_weather(session_key: int) -> list[dict[str, Any]]:
    """Возвращает погодные данные конкретной сессии."""
    return fetch(
        "weather",
        {"session_key": session_key},
        allow_not_found=True,
    )


def get_positions(session_key: int) -> list[dict[str, Any]]:
    """
    Возвращает историю позиций пилотов конкретной сессии.

    Для отдельных сессий OpenF1 может не содержать данные о позициях.
    В таком случае возвращается пустой список.
    """
    return fetch(
        "position",
        {"session_key": session_key},
        allow_not_found=True,
    )