-- =============================================
-- F1 Data Pipeline — схема сырых данных
-- PostgreSQL (publisher)
-- =============================================

-- Сессии (гонки, квалификации, практики)
CREATE TABLE IF NOT EXISTS sessions (
    session_key         INTEGER PRIMARY KEY,
    session_name        VARCHAR(100),       -- 'Race', 'Qualifying', 'Practice 1' и т.д.
    session_type        VARCHAR(50),        -- 'Race', 'Qualifying', 'Practice'
    date_start          TIMESTAMP,
    date_end            TIMESTAMP,
    gmt_offset          VARCHAR(10),
    location            VARCHAR(100),       -- город
    country_name        VARCHAR(100),
    country_code        VARCHAR(10),
    circuit_key         INTEGER,
    circuit_short_name  VARCHAR(100),
    year                INTEGER,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- Пилоты
CREATE TABLE IF NOT EXISTS drivers (
    driver_number       INTEGER,
    session_key         INTEGER,
    broadcast_name      VARCHAR(100),
    full_name           VARCHAR(100),
    name_acronym        VARCHAR(10),        -- 'VER', 'HAM', 'LEC' и т.д.
    team_name           VARCHAR(100),
    team_colour         VARCHAR(10),        -- hex цвет команды
    country_code        VARCHAR(10),
    headshot_url        TEXT,
    created_at          TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (driver_number, session_key)
);

-- Времена кругов
CREATE TABLE IF NOT EXISTS laps (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    lap_number          INTEGER,
    lap_duration        FLOAT,              -- время круга в секундах
    duration_sector_1   FLOAT,
    duration_sector_2   FLOAT,
    duration_sector_3   FLOAT,
    i1_speed            FLOAT,              -- скорость в точке замера 1
    i2_speed            FLOAT,
    st_speed            FLOAT,             -- скорость на финишной прямой
    is_pit_out_lap      BOOLEAN,
    date_start          TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_laps_session ON laps(session_key);
CREATE INDEX IF NOT EXISTS idx_laps_driver ON laps(driver_number);

-- Пит-стопы
CREATE TABLE IF NOT EXISTS pit_stops (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    lap_number          INTEGER,
    pit_duration        FLOAT,             -- время пит-стопа в секундах
    date                TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pit_session ON pit_stops(session_key);
CREATE INDEX IF NOT EXISTS idx_pit_driver ON pit_stops(driver_number);

-- Погода на трассе
CREATE TABLE IF NOT EXISTS weather (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    date                TIMESTAMP,
    air_temperature     FLOAT,             -- температура воздуха (°C)
    track_temperature   FLOAT,             -- температура трассы (°C)
    humidity            FLOAT,             -- влажность (%)
    pressure            FLOAT,             -- давление (мбар)
    wind_speed          FLOAT,             -- скорость ветра (м/с)
    wind_direction      INTEGER,           -- направление ветра (градусы)
    rainfall            BOOLEAN,           -- был ли дождь
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_weather_session ON weather(session_key);

-- Позиции в гонке
CREATE TABLE IF NOT EXISTS positions (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    date                TIMESTAMP,
    position            INTEGER,           -- позиция на трассе
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_positions_session ON positions(session_key);
CREATE INDEX IF NOT EXISTS idx_positions_driver ON positions(driver_number);

-- =============================================
-- Логическая репликация (publisher → subscriber)
-- =============================================
-- Создаём publication для всех таблиц
-- (subscriber настраивается отдельно)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication WHERE pubname = 'f1_publication'
    ) THEN
        CREATE PUBLICATION f1_publication FOR TABLE
            sessions,
            drivers,
            laps,
            pit_stops,
            weather,
            positions;
    END IF;
END
$$;
