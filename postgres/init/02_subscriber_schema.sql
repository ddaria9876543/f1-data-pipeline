-- =============================================
-- F1 Data Pipeline — схема для subscriber
-- Такая же структура как у publisher
-- =============================================

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

CREATE TABLE IF NOT EXISTS pit_stops (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    lap_number          INTEGER,
    pit_duration        FLOAT,
    date                TIMESTAMP,
    created_at          TIMESTAMP DEFAULT NOW()
);

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

CREATE TABLE IF NOT EXISTS positions (
    id                  SERIAL PRIMARY KEY,
    session_key         INTEGER,
    driver_number       INTEGER,
    date                TIMESTAMP,
    position            INTEGER,
    created_at          TIMESTAMP DEFAULT NOW()
);

-- Создаём subscription (получает данные от publisher)
-- Выполняется только если subscription ещё не существует
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_subscription WHERE subname = 'f1_subscription'
    ) THEN
        CREATE SUBSCRIPTION f1_subscription
            CONNECTION 'host=postgres-publisher port=5432 dbname=f1_raw user=postgres password=f1pass123'
            PUBLICATION f1_publication;
    END IF;
END
$$;
