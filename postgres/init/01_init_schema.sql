
-- =============================================
-- F1 Data Pipeline
-- PostgreSQL: RAW-слой
-- =============================================

-- 1. Сессии
CREATE TABLE IF NOT EXISTS sessions (
    session_key         INTEGER PRIMARY KEY,
    session_name        VARCHAR(100),
    session_type        VARCHAR(50),
    date_start          TIMESTAMP,
    date_end            TIMESTAMP,
    gmt_offset          VARCHAR(10),
    location            VARCHAR(100),
    country_name        VARCHAR(100),
    country_code        VARCHAR(10),
    circuit_key         INTEGER,
    circuit_short_name  VARCHAR(100),
    year                INTEGER,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- 2. Пилоты
CREATE TABLE IF NOT EXISTS drivers (
    driver_number       INTEGER,
    session_key         INTEGER,
    broadcast_name      VARCHAR(100),
    full_name           VARCHAR(100),
    name_acronym        VARCHAR(10),
    team_name           VARCHAR(100),
    team_colour         VARCHAR(10),
    country_code        VARCHAR(10),
    headshot_url        TEXT,
    created_at          TIMESTAMP DEFAULT NOW(),
    PRIMARY KEY (driver_number, session_key)
);

-- 3. Времена кругов
CREATE TABLE IF NOT EXISTS laps (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    lap_number          INTEGER,
    lap_duration        FLOAT,
    duration_sector_1   FLOAT,
    duration_sector_2   FLOAT,
    duration_sector_3   FLOAT,
    i1_speed            FLOAT,
    i2_speed            FLOAT,
    st_speed            FLOAT,
    is_pit_out_lap      BOOLEAN,
    date_start          TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_laps_session
    ON laps(session_key);

CREATE INDEX IF NOT EXISTS idx_laps_driver
    ON laps(driver_number);

-- 4. Пит-стопы
CREATE TABLE IF NOT EXISTS pit_stops (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    lap_number          INTEGER,
    pit_duration        FLOAT,
    date                TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_pit_session
    ON pit_stops(session_key);

CREATE INDEX IF NOT EXISTS idx_pit_driver
    ON pit_stops(driver_number);

-- 5. Погода
CREATE TABLE IF NOT EXISTS weather (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    date                TIMESTAMP,
    air_temperature     FLOAT,
    track_temperature   FLOAT,
    humidity            FLOAT,
    pressure            FLOAT,
    wind_speed          FLOAT,
    wind_direction      INTEGER,
    rainfall            BOOLEAN,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_weather_session
    ON weather(session_key);

-- 6. Позиции пилотов
CREATE TABLE IF NOT EXISTS positions (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    date                TIMESTAMP,
    position            INTEGER,
    created_at          TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_positions_session
    ON positions(session_key);

CREATE INDEX IF NOT EXISTS idx_positions_driver
    ON positions(driver_number);
