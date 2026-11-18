
"""
loader.py — загрузка данных OpenF1 API в PostgreSQL.

Поддерживает:
- UPSERT для сессий и пилотов;
- транзакционную замену данных сессии;
- пакетную вставку;
- обработку пустых ответов;
- закрытие соединений;
- логирование.
"""

import logging
import os
from contextlib import closing

import psycopg2
from psycopg2.extras import execute_values


logger = logging.getLogger(__name__)

BATCH_SIZE = 500


# --------------------------------------------------
# Подключение к PostgreSQL
# --------------------------------------------------

def get_connection():
    """Создаёт подключение к PostgreSQL."""

    password = os.environ["POSTGRES_PUBLICIST_PASSWORD"]

    return psycopg2.connect(
        host=os.getenv(
            "POSTGRES_HOST",
            "postgres-publisher"
        ),
        port=int(os.getenv("POSTGRES_PORT", "5432")),
        dbname=os.getenv(
            "POSTGRES_PUBLICIST_DB",
            "f1_raw"
        ),
        user=os.getenv(
            "POSTGRES_PUBLICIST_USER",
            "postgres"
        ),
        password=password,
        connect_timeout=10,
    )


def validate_records(records, name):
    """Проверяет формат данных перед загрузкой."""

    if not isinstance(records, list):
        raise TypeError(
            f"{name}: ожидался список, "
            f"получено {type(records).__name__}"
        )

    for index, record in enumerate(records):
        if not isinstance(record, dict):
            raise TypeError(
                f"{name}: запись {index} "
                "не является словарём"
            )


def execute_batch(cursor, query, rows):
    """Выполняет пакетную вставку."""

    if not rows:
        return

    execute_values(
        cursor,
        query,
        rows,
        page_size=BATCH_SIZE,
    )


# --------------------------------------------------
# 1. Сессии — UPSERT
# --------------------------------------------------

def upsert_sessions(sessions: list) -> int:
    """Добавляет или обновляет сессии."""

    validate_records(sessions, "sessions")

    if not sessions:
        logger.info("sessions: нет данных для загрузки")
        return 0

    # Убираем повторяющиеся session_key
    unique = {}

    for session in sessions:
        key = session.get("session_key")

        if key is None:
            raise ValueError(
                "sessions: отсутствует session_key"
            )

        unique[key] = session

    rows = [
        (
            s["session_key"],
            s.get("session_name"),
            s.get("session_type"),
            s.get("date_start"),
            s.get("date_end"),
            s.get("gmt_offset"),
            s.get("location"),
            s.get("country_name"),
            s.get("country_code"),
            s.get("circuit_key"),
            s.get("circuit_short_name"),
            s.get("year"),
        )
        for s in unique.values()
    ]

    query = """
        INSERT INTO sessions (
            session_key,
            session_name,
            session_type,
            date_start,
            date_end,
            gmt_offset,
            location,
            country_name,
            country_code,
            circuit_key,
            circuit_short_name,
            year
        )
        VALUES %s

        ON CONFLICT (session_key)
        DO UPDATE SET
            session_name = EXCLUDED.session_name,
            session_type = EXCLUDED.session_type,
            date_start = EXCLUDED.date_start,
            date_end = EXCLUDED.date_end,
            gmt_offset = EXCLUDED.gmt_offset,
            location = EXCLUDED.location,
            country_name = EXCLUDED.country_name,
            country_code = EXCLUDED.country_code,
            circuit_key = EXCLUDED.circuit_key,
            circuit_short_name = EXCLUDED.circuit_short_name,
            year = EXCLUDED.year;
    """

    with closing(get_connection()) as conn:
        with conn:
            with conn.cursor() as cursor:
                execute_batch(cursor, query, rows)

    logger.info(
        "sessions: обработано %s записей",
        len(rows)
    )

    return len(rows)


# --------------------------------------------------
# 2. Пилоты — UPSERT
# --------------------------------------------------

def upsert_drivers(drivers: list) -> int:
    """Добавляет или обновляет информацию о пилотах."""

    validate_records(drivers, "drivers")

    if not drivers:
        logger.info("drivers: нет данных для загрузки")
        return 0

    unique = {}

    for driver in drivers:
        key = (
            driver.get("driver_number"),
            driver.get("session_key"),
        )

        if None in key:
            raise ValueError(
                "drivers: отсутствует ключ пилота"
            )

        unique[key] = driver

    rows = [
        (
            d["driver_number"],
            d["session_key"],
            d.get("broadcast_name"),
            d.get("full_name"),
            d.get("name_acronym"),
            d.get("team_name"),
            d.get("team_colour"),
            d.get("country_code"),
            d.get("headshot_url"),
        )
        for d in unique.values()
    ]

    query = """
        INSERT INTO drivers (
            driver_number,
            session_key,
            broadcast_name,
            full_name,
            name_acronym,
            team_name,
            team_colour,
            country_code,
            headshot_url
        )
        VALUES %s

        ON CONFLICT (driver_number, session_key)
        DO UPDATE SET
            broadcast_name = EXCLUDED.broadcast_name,
            full_name = EXCLUDED.full_name,
            name_acronym = EXCLUDED.name_acronym,
            team_name = EXCLUDED.team_name,
            team_colour = EXCLUDED.team_colour,
            country_code = EXCLUDED.country_code,
            headshot_url = EXCLUDED.headshot_url;
    """

    with closing(get_connection()) as conn:
        with conn:
            with conn.cursor() as cursor:
                execute_batch(cursor, query, rows)

    logger.info(
        "drivers: обработано %s записей",
        len(rows)
    )

    return len(rows)


# --------------------------------------------------
# Общая функция замены данных сессии
# --------------------------------------------------

def replace_session_data(
    table_name,
    columns,
    rows,
    session_key,
):
    """
    Удаляет старые записи сессии и вставляет новые.

    DELETE и INSERT выполняются в одной транзакции.
    При ошибке происходит ROLLBACK.

    Пустой список не удаляет старые данные.
    """

    if not rows:
        logger.warning(
            "%s: пустой набор для сессии %s, "
            "старые данные сохранены",
            table_name,
            session_key,
        )
        return 0

    # Используем только заранее заданные таблицы и поля
    allowed_columns = {
        "laps": (
            "session_key", "driver_number", "lap_number",
            "lap_duration", "duration_sector_1",
            "duration_sector_2", "duration_sector_3",
            "i1_speed", "i2_speed", "st_speed",
            "is_pit_out_lap", "date_start",
        ),
        "pit_stops": (
            "session_key", "driver_number",
            "lap_number", "pit_duration", "date",
        ),
        "weather": (
            "session_key", "date", "air_temperature",
            "track_temperature", "humidity", "pressure",
            "wind_speed", "wind_direction", "rainfall",
        ),
        "positions": (
            "session_key", "driver_number",
            "date", "position",
        ),
    }

    if allowed_columns.get(table_name) != tuple(columns):
        raise ValueError(
            f"Недопустимая таблица или набор полей: {table_name}"
        )

    column_names = ", ".join(columns)

    insert_query = f"""
        INSERT INTO {table_name} ({column_names})
        VALUES %s;
    """

    delete_query = f"""
        DELETE FROM {table_name}
        WHERE session_key = %s;
    """

    with closing(get_connection()) as conn:
        with conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    delete_query,
                    (session_key,)
                )

                execute_batch(
                    cursor,
                    insert_query,
                    rows,
                )

    logger.info(
        "%s: записано %s строк для сессии %s",
        table_name,
        len(rows),
        session_key,
    )

    return len(rows)


# --------------------------------------------------
# 3. Круги
# --------------------------------------------------

def insert_laps(laps: list, session_key: int) -> int:
    """Заменяет данные о кругах выбранной сессии."""

    validate_records(laps, "laps")

    rows = [
        (
            session_key,
            lap.get("driver_number"),
            lap.get("lap_number"),
            lap.get("lap_duration"),
            lap.get("duration_sector_1"),
            lap.get("duration_sector_2"),
            lap.get("duration_sector_3"),
            lap.get("i1_speed"),
            lap.get("i2_speed"),
            lap.get("st_speed"),
            lap.get("is_pit_out_lap"),
            lap.get("date_start"),
        )
        for lap in laps
    ]

    columns = [
        "session_key",
        "driver_number",
        "lap_number",
        "lap_duration",
        "duration_sector_1",
        "duration_sector_2",
        "duration_sector_3",
        "i1_speed",
        "i2_speed",
        "st_speed",
        "is_pit_out_lap",
        "date_start",
    ]

    return replace_session_data(
        "laps",
        columns,
        rows,
        session_key,
    )


# --------------------------------------------------
# 4. Пит-стопы
# --------------------------------------------------

def insert_pit_stops(
    pit_stops: list,
    session_key: int
) -> int:
    """Заменяет данные о пит-стопах."""

    validate_records(pit_stops, "pit_stops")

    rows = [
        (
            session_key,
            p.get("driver_number"),
            p.get("lap_number"),
            p.get("pit_duration"),
            p.get("date"),
        )
        for p in pit_stops
    ]

    columns = [
        "session_key",
        "driver_number",
        "lap_number",
        "pit_duration",
        "date",
    ]

    return replace_session_data(
        "pit_stops",
        columns,
        rows,
        session_key,
    )


# --------------------------------------------------
# 5. Погода
# --------------------------------------------------

def insert_weather(
    weather: list,
    session_key: int
) -> int:
    """Заменяет погодные данные сессии."""

    validate_records(weather, "weather")

    rows = [
        (
            session_key,
            w.get("date"),
            w.get("air_temperature"),
            w.get("track_temperature"),
            w.get("humidity"),
            w.get("pressure"),
            w.get("wind_speed"),
            w.get("wind_direction"),
            (
                bool(w.get("rainfall"))
                if w.get("rainfall") is not None
                else None
            ),
        )
        for w in weather
    ]

    columns = [
        "session_key",
        "date",
        "air_temperature",
        "track_temperature",
        "humidity",
        "pressure",
        "wind_speed",
        "wind_direction",
        "rainfall",
    ]

    return replace_session_data(
        "weather",
        columns,
        rows,
        session_key,
    )


# --------------------------------------------------
# 6. Позиции пилотов
# --------------------------------------------------

def insert_positions(
    positions: list,
    session_key: int
) -> int:
    """Заменяет данные о позициях пилотов."""

    validate_records(positions, "positions")

    rows = [
        (
            session_key,
            p.get("driver_number"),
            p.get("date"),
            p.get("position"),
        )
        for p in positions
    ]

    columns = [
        "session_key",
        "driver_number",
        "date",
        "position",
    ]

    return replace_session_data(
        "positions",
        columns,
        rows,
        session_key,
    )
