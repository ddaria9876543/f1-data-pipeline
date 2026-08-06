-- stg_sessions.sql
-- Чистим и типизируем сессии

SELECT
    session_key,
    session_name,
    session_type,
    date_start,
    date_end,
    location,
    country_name,
    country_code,
    circuit_short_name,
    year
FROM {{ source('f1_raw', 'sessions') }}
WHERE session_key IS NOT NULL
