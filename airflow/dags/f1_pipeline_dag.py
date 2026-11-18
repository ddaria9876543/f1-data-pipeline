
"""
F1 Data Pipeline
OpenF1 API -> Python -> PostgreSQL

Режимы:
1. incremental — ежедневная загрузка актуальных данных
2. backfill — ручная загрузка исторических сезонов
"""

import logging
from datetime import datetime, timedelta, timezone

from airflow import DAG
from airflow.operators.bash import BashOperator
from airflow.operators.python import PythonOperator

import extractor
import loader


logger = logging.getLogger(__name__)

# Настройки
HISTORY_YEARS = [2023, 2024, 2025]
LOOKBACK_DAYS = 14


default_args = {
    "owner": "f1_pipeline",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}


dag = DAG(
    dag_id="f1_data_pipeline",
    description="ETL: OpenF1 API -> PostgreSQL",
    schedule_interval="0 6 * * *",
    start_date=datetime(2026, 1, 1),
    catchup=False,
    default_args=default_args,
    max_active_runs=1,
    is_paused_upon_creation=True,
    tags=["f1", "etl", "openf1", "incremental"],
)


# --------------------------------------------------
# Вспомогательные функции
# --------------------------------------------------

def parse_datetime(value):
    """Преобразует дату OpenF1 в UTC."""
    if not value:
        return None

    if isinstance(value, datetime):
        result = value
    else:
        result = datetime.fromisoformat(
            str(value).replace("Z", "+00:00")
        )

    if result.tzinfo is None:
        result = result.replace(tzinfo=timezone.utc)

    return result.astimezone(timezone.utc)


def get_session_keys(context):
    """Получает session_key из XCom."""
    keys = context["ti"].xcom_pull(
        task_ids="load_sessions",
        key="session_keys",
    )
    return keys or []


# --------------------------------------------------
# Task 1. Загрузка сессий
# --------------------------------------------------

def load_sessions_task(**context):
    dag_run = context["dag_run"]
    config = dag_run.conf or {}

    mode = config.get("mode", "incremental")

    if mode not in ("incremental", "backfill"):
        raise ValueError(f"Неизвестный режим: {mode}")

    all_sessions = []

    if mode == "backfill":
        # Историческая загрузка только вручную
        if dag_run.run_type != "manual":
            raise ValueError(
                "Backfill разрешён только при ручном запуске"
            )

        years = config.get("years", HISTORY_YEARS)

        if (
            not isinstance(years, list)
            or not years
            or any(
                type(year) is not int
                or year < 2023
                or year > datetime.now(timezone.utc).year
                for year in years
            )
        ):
            raise ValueError(
                "Укажи корректный список годов для backfill"
            )

        logger.info("Историческая загрузка: %s", years)

        for year in sorted(set(years)):
            sessions = extractor.get_sessions(year)
            all_sessions.extend(sessions)

    else:
        # Регулярная загрузка
        now = datetime.now(timezone.utc)
        window_start = now - timedelta(days=LOOKBACK_DAYS)

        logger.info(
            "Инкрементальная загрузка: %s — %s",
            window_start,
            now,
        )

        years = range(window_start.year, now.year + 1)

        for year in years:
            sessions = extractor.get_sessions(year)

            for session in sessions:
                date_end = parse_datetime(
                    session.get("date_end")
                )

                # Обрабатываем только завершённые сессии
                if (
                    date_end is not None
                    and window_start <= date_end <= now
                ):
                    all_sessions.append(session)

    # Убираем возможные дубликаты сессий
    unique_sessions = {}

    for session in all_sessions:
        session_key = session.get("session_key")

        if session_key is not None:
            unique_sessions[session_key] = session

    selected_sessions = list(unique_sessions.values())

    if selected_sessions:
        loader.upsert_sessions(selected_sessions)

    session_keys = list(unique_sessions.keys())

    context["ti"].xcom_push(
        key="session_keys",
        value=session_keys,
    )

    logger.info(
        "Режим: %s. Выбрано сессий: %s",
        mode,
        len(session_keys),
    )


# --------------------------------------------------
# Task 2. Пилоты
# --------------------------------------------------

def load_drivers_task(**context):
    session_keys = get_session_keys(context)

    for session_key in session_keys:
        drivers = extractor.get_drivers(session_key)
        loader.upsert_drivers(drivers)

    logger.info("Обработано сессий: %s", len(session_keys))


# --------------------------------------------------
# Task 3. Круги
# --------------------------------------------------

def load_laps_task(**context):
    session_keys = get_session_keys(context)

    for session_key in session_keys:
        laps = extractor.get_laps(session_key)
        loader.insert_laps(laps, session_key)

    logger.info("Обработано сессий: %s", len(session_keys))


# --------------------------------------------------
# Task 4. Пит-стопы
# --------------------------------------------------

def load_pit_stops_task(**context):
    session_keys = get_session_keys(context)

    for session_key in session_keys:
        pit_stops = extractor.get_pit_stops(session_key)
        loader.insert_pit_stops(pit_stops, session_key)

    logger.info("Обработано сессий: %s", len(session_keys))


# --------------------------------------------------
# Task 5. Погода
# --------------------------------------------------

def load_weather_task(**context):
    session_keys = get_session_keys(context)

    for session_key in session_keys:
        weather = extractor.get_weather(session_key)
        loader.insert_weather(weather, session_key)

    logger.info("Обработано сессий: %s", len(session_keys))


# --------------------------------------------------
# Task 6. Позиции пилотов
# --------------------------------------------------

def load_positions_task(**context):
    session_keys = get_session_keys(context)

    for session_key in session_keys:
        positions = extractor.get_positions(session_key)
        loader.insert_positions(positions, session_key)

    logger.info("Обработано сессий: %s", len(session_keys))


# --------------------------------------------------
# Определение задач Airflow
# --------------------------------------------------

t1_sessions = PythonOperator(
    task_id="load_sessions",
    python_callable=load_sessions_task,
    dag=dag,
)

t2_drivers = PythonOperator(
    task_id="load_drivers",
    python_callable=load_drivers_task,
    dag=dag,
)

t3_laps = PythonOperator(
    task_id="load_laps",
    python_callable=load_laps_task,
    dag=dag,
)

t4_pit_stops = PythonOperator(
    task_id="load_pit_stops",
    python_callable=load_pit_stops_task,
    dag=dag,
)

t5_weather = PythonOperator(
    task_id="load_weather",
    python_callable=load_weather_task,
    dag=dag,
)

t6_positions = PythonOperator(
    task_id="load_positions",
    python_callable=load_positions_task,
    dag=dag,
)

# Task 7. Построение витрин и Data Quality
t7_dbt = BashOperator(
    task_id="run_dbt",
    bash_command=(
        "dbt build "
        "--project-dir /usr/app/dbt "
        "--profiles-dir /usr/app/profiles"
    ),
    dag=dag,
)
# --------------------------------------------------
# Порядок выполнения
# --------------------------------------------------

(
    t1_sessions
    >> t2_drivers
    >> t3_laps
    >> t4_pit_stops
    >> t5_weather
    >> t6_positions
    >> t7_dbt
)