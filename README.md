# 🏎️ F1 Data Pipeline

**Автор:** Дарья Байгина

## О проекте

F1 Data Pipeline — ETL-пайплайн для автоматической загрузки, обработки и анализа данных чемпионата Formula 1.

Данные за сезоны **2023–2025** загружаются из OpenF1 API с помощью Apache Airflow, сохраняются в PostgreSQL, преобразуются в аналитические витрины с помощью dbt и используются для построения BI-дашборда в Metabase.

Система автоматически:

- получает данные из OpenF1 API;
- загружает сырые данные в PostgreSQL;
- обрабатывает ошибки API и выполняет повторные запросы;
- очищает и преобразует данные;
- формирует staging-модели и аналитические витрины;
- выполняет проверки качества данных;
- предоставляет подготовленные данные для BI-дашборда.

---

## 📊 Дашборд

Для визуализации аналитических витрин используется Metabase.

Дашборд позволяет анализировать:

- результаты гонок, пилотов и команд;
- распределение побед между командами и пилотами;
- продолжительность пит-стопов;
- лучшие времена круга;
- погодные условия на трассах;
- географию проведения гонок.

<details>
<summary>Посмотреть дашборд</summary>

![F1 Analytics Dashboard](images/dashboard.png)

</details>

---

## 🏗 Архитектура

```text
OpenF1 API
     │
     ▼
Apache Airflow
     │
     ▼
PostgreSQL
  Raw Layer
     │
     ▼
    dbt
     │
     ├── Staging
     ├── Data Marts
     └── Data Quality
     │
     ▼
  Metabase
BI Dashboard
```

---

## 🛠 Технологии

| Компонент | Технология |
|---|---|
| Язык | Python |
| Источник данных | OpenF1 API |
| Оркестрация | Apache Airflow |
| База данных | PostgreSQL |
| Трансформация данных | dbt |
| BI | Metabase |
| Контейнеризация | Docker, Docker Compose |
| Контроль версий | Git, GitHub |

---

## ⚙️ ETL-пайплайн

Airflow загружает из OpenF1 API данные о:

- сессиях;
- пилотах и командах;
- кругах;
- пит-стопах;
- позициях пилотов;
- погодных условиях.

Основной DAG:

```text
load_sessions
      ↓
load_drivers
      ↓
load_laps
      ↓
load_pit_stops
      ↓
load_weather
      ↓
load_positions
```

Для работы с ограничениями API реализованы повторные запросы, обработка ошибок и контроль частоты обращений.

<!-- После добавления изображения:
![Airflow DAG](images/airflow_dag.png)
-->

---

## 🔄 Преобразование данных

Для преобразования данных используется dbt.

### Staging

- `stg_sessions`
- `stg_drivers`
- `stg_laps`
- `stg_pit_stops`
- `stg_positions`
- `stg_weather`

### Аналитические витрины

| Витрина | Назначение |
|---|---|
| `mart_driver_performance` | Анализ результатов пилотов |
| `mart_team_comparison` | Сравнение команд |
| `mart_fastest_laps` | Лучшие круги по трассам |
| `mart_pit_stop_impact` | Анализ пит-стопов |
| `mart_weather_analysis` | Анализ погодных условий |
| `mart_race_summary` | Сводная информация по гонкам |

### Data Quality

Для контроля качества данных используются dbt-тесты и отдельные модели:

- `dq_lap_anomalies`;
- `dq_weather_anomalies`.

---

## 📈 BI-дашборд

В Metabase реализованы:

- KPI по количеству гонок, пилотов, команд и дождевых гонок;
- сравнение результатов команд;
- количество побед пилотов;
- распределение побед между командами;
- анализ лучших кругов;
- анализ пит-стопов;
- анализ температуры воздуха;
- карта проведения гонок.

---

## 📂 Структура проекта

```text
f1-data-pipeline/
├── airflow/
│   └── dags/
│       ├── extractor.py
│       ├── loader.py
│       └── f1_pipeline_dag.py
│
├── dbt/
│   └── f1/
│       └── models/
│           ├── staging/
│           ├── marts/
│           └── data_quality/
│
├── postgres/
├── clickhouse/
├── .dbt_template/
├── Dockerfile
├── docker-compose.yaml
├── requirements.txt
└── README.md
```

---

## 🚀 Запуск

### 1. Клонировать репозиторий

```bash
git clone https://github.com/ddaria9876543/f1-data-pipeline.git
cd f1-data-pipeline
```

### 2. Настроить окружение

Создать `.env` на основе шаблона `.env_template` и при необходимости изменить параметры подключения.

Для dbt скопировать `.dbt_template` в `.dbt`.

### 3. Запустить контейнеры

```bash
docker compose up -d
```

### 4. Запустить DAG

Открыть Airflow:

```text
http://localhost:8082
```

и запустить:

```text
f1_data_pipeline
```

### 5. Построить аналитические модели

```bash
docker exec -it f1_dbt dbt run --target postgres --profiles-dir /home/airflow/.dbt
```

Запустить тесты:

```bash
docker exec -it f1_dbt dbt test --target postgres --profiles-dir /home/airflow/.dbt
```

### 6. Открыть Metabase

```text
http://localhost:3000
```

---

## 🔮 Возможные улучшения

- инкрементальная загрузка новых данных;
- автоматический запуск dbt из Airflow;
- CI/CD с GitHub Actions;
- развитие аналитического слоя в ClickHouse.
