
FROM apache/airflow:2.8.2-python3.10

USER root

# Системные зависимости
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    curl \
    git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Python-зависимости
COPY requirements.txt /requirements.txt

RUN pip install --no-cache-dir \
    -r /requirements.txt \
    && pip check
