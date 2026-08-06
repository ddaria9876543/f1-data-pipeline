"""
f1_pipeline_dag.py — главный DAG
Запускается каждый день, забирает данные из OpenF1 API → PostgreSQL
"""
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

import extractor
import loader

# ── Настройки DAG ──────────────────────────────────────────
default_args = {
    "owner": "f1_pipeline",
    "retries": 2,
    "retry_delay": timedelta(minutes=5),
    "email_on_failure": False,
}

dag = DAG(
    dag_id="f1_data_pipeline",
    description="Забираем данные F1 из OpenF1 API и кладём в PostgreSQL",
    schedule_interval="0 6 * * *",   # каждый день в 6:00
    start_date=datetime(2024, 1, 1),
    catchup=False,
    default_args=default_args,
    tags=["f1", "etl", "openf1"],
)

YEARS = [2023, 2024, 2025]


# ── Task 1: загрузить сессии ────────────────────────────────
def load_sessions_task(**context):
    all_sessions = []
    for year in YEARS:
        sessions = extractor.get_sessions(year)
        loader.upsert_sessions(sessions)
        all_sessions.extend(sessions)

    # передаём session_key'и дальше через XCom
    session_keys = [s["session_key"] for s in all_sessions if s.get("session_key")]
    context["ti"].xcom_push(key="session_keys", value=session_keys)
    print(f"Загружено сессий: {len(session_keys)}")


# ── Task 2: загрузить пилотов ───────────────────────────────
def load_drivers_task(**context):
    session_keys = context["ti"].xcom_pull(key="session_keys", task_ids="load_sessions")
    for session_key in session_keys:
        drivers = extractor.get_drivers(session_key)
        loader.upsert_drivers(drivers)


# ── Task 3: загрузить круги ─────────────────────────────────
def load_laps_task(**context):
    session_keys = context["ti"].xcom_pull(key="session_keys", task_ids="load_sessions")
    # Грузим только гоночные сессии (Race) — там самые интересные данные
    for session_key in session_keys:
        laps = extractor.get_laps(session_key)
        loader.insert_laps(laps, session_key)


# ── Task 4: загрузить пит-стопы ─────────────────────────────
def load_pit_stops_task(**context):
    session_keys = context["ti"].xcom_pull(key="session_keys", task_ids="load_sessions")
    for session_key in session_keys:
        pit_stops = extractor.get_pit_stops(session_key)
        loader.insert_pit_stops(pit_stops, session_key)


# ── Task 5: загрузить погоду ────────────────────────────────
def load_weather_task(**context):
    session_keys = context["ti"].xcom_pull(key="session_keys", task_ids="load_sessions")
    for session_key in session_keys:
        weather = extractor.get_weather(session_key)
        loader.insert_weather(weather, session_key)


# ── Task 6: загрузить позиции ───────────────────────────────
def load_positions_task(**context):
    session_keys = context["ti"].xcom_pull(key="session_keys", task_ids="load_sessions")
    for session_key in session_keys:
        positions = extractor.get_positions(session_key)
        loader.insert_positions(positions, session_key)


# ── Определяем задачи ───────────────────────────────────────
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

# ── Порядок выполнения ──────────────────────────────────────
#
#              ┌─ t2_drivers  ─┐
#              ├─ t3_laps     ─┤
# t1_sessions ─┤─ t4_pit_stops─┼─ (конец)
#              ├─ t5_weather  ─┤
#              └─ t6_positions ┘
#
t1_sessions >> t2_drivers >> t3_laps >> t4_pit_stops >> t5_weather >> t6_positions
