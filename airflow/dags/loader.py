"""
loader.py — кладёт данные из OpenF1 API в PostgreSQL
"""
import logging
import os
import psycopg2
from psycopg2.extras import execute_values

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger(__name__)


def get_connection():
    """Подключение к PostgreSQL."""
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres-publisher"),
        port=5432,
        dbname=os.getenv("POSTGRES_PUBLICIST_DB", "f1_raw"),
        user=os.getenv("POSTGRES_PUBLICIST_USER", "postgres"),
        password=os.getenv("POSTGRES_PUBLICIST_PASSWORD", "f1pass123"),
    )


def upsert_sessions(sessions: list) -> int:
    """Загружаем сессии (upsert по session_key)."""
    if not sessions:
        return 0

    rows = []
    for s in sessions:
        rows.append((
            s.get("session_key"),
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
        ))

    sql = """
        INSERT INTO sessions (
            session_key, session_name, session_type,
            date_start, date_end, gmt_offset,
            location, country_name, country_code,
            circuit_key, circuit_short_name, year
        ) VALUES %s
        ON CONFLICT (session_key) DO UPDATE SET
            session_name = EXCLUDED.session_name,
            date_end     = EXCLUDED.date_end;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            execute_values(cur, sql, rows)
    logger.info(f"sessions: загружено {len(rows)} записей")
    return len(rows)


def upsert_drivers(drivers: list) -> int:
    """Загружаем пилотов (upsert по driver_number + session_key)."""
    if not drivers:
        return 0

    rows = []
    for d in drivers:
        rows.append((
            d.get("driver_number"),
            d.get("session_key"),
            d.get("broadcast_name"),
            d.get("full_name"),
            d.get("name_acronym"),
            d.get("team_name"),
            d.get("team_colour"),
            d.get("country_code"),
            d.get("headshot_url"),
        ))

    sql = """
        INSERT INTO drivers (
            driver_number, session_key, broadcast_name,
            full_name, name_acronym, team_name,
            team_colour, country_code, headshot_url
        ) VALUES %s
        ON CONFLICT (driver_number, session_key) DO UPDATE SET
            team_name  = EXCLUDED.team_name,
            team_colour = EXCLUDED.team_colour;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            execute_values(cur, sql, rows)
    logger.info(f"drivers: загружено {len(rows)} записей")
    return len(rows)


def insert_laps(laps: list, session_key: int) -> int:
    """Загружаем круги (сначала удаляем старые для сессии, потом вставляем)."""
    if not laps:
        return 0

    rows = []
    for lap in laps:
        rows.append((
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
        ))

    sql = """
        INSERT INTO laps (
            session_key, driver_number, lap_number,
            lap_duration, duration_sector_1, duration_sector_2, duration_sector_3,
            i1_speed, i2_speed, st_speed,
            is_pit_out_lap, date_start
        ) VALUES %s
        ON CONFLICT DO NOTHING;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM laps WHERE session_key = %s", (session_key,))
            execute_values(cur, sql, rows)
    logger.info(f"laps: загружено {len(rows)} записей для сессии {session_key}")
    return len(rows)


def insert_pit_stops(pit_stops: list, session_key: int) -> int:
    """Загружаем пит-стопы."""
    if not pit_stops:
        return 0

    rows = []
    for p in pit_stops:
        rows.append((
            session_key,
            p.get("driver_number"),
            p.get("lap_number"),
            p.get("pit_duration"),
            p.get("date"),
        ))

    sql = """
        INSERT INTO pit_stops (
            session_key, driver_number, lap_number, pit_duration, date
        ) VALUES %s
        ON CONFLICT DO NOTHING;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM pit_stops WHERE session_key = %s", (session_key,))
            execute_values(cur, sql, rows)
    logger.info(f"pit_stops: загружено {len(rows)} записей для сессии {session_key}")
    return len(rows)


def insert_weather(weather: list, session_key: int) -> int:
    """Загружаем погоду."""
    if not weather:
        return 0

    rows = []
    for w in weather:
        rows.append((
            session_key,
            w.get("date"),
            w.get("air_temperature"),
            w.get("track_temperature"),
            w.get("humidity"),
            w.get("pressure"),
            w.get("wind_speed"),
            w.get("wind_direction"),
            bool(w.get("rainfall")) if w.get("rainfall") is not None else None,
        ))

    sql = """
        INSERT INTO weather (
            session_key, date, air_temperature, track_temperature,
            humidity, pressure, wind_speed, wind_direction, rainfall
        ) VALUES %s
        ON CONFLICT DO NOTHING;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM weather WHERE session_key = %s", (session_key,))
            execute_values(cur, sql, rows)
    logger.info(f"weather: загружено {len(rows)} записей для сессии {session_key}")
    return len(rows)


def insert_positions(positions: list, session_key: int) -> int:
    """Загружаем позиции."""
    if not positions:
        return 0

    rows = []
    for p in positions:
        rows.append((
            session_key,
            p.get("driver_number"),
            p.get("date"),
            p.get("position"),
        ))

    sql = """
        INSERT INTO positions (
            session_key, driver_number, date, position
        ) VALUES %s
        ON CONFLICT DO NOTHING;
    """
    with get_connection() as conn:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM positions WHERE session_key = %s", (session_key,))
            execute_values(cur, sql, rows)
    logger.info(f"positions: загружено {len(rows)} записей для сессии {session_key}")
    return len(rows)
