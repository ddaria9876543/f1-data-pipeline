-- mart_weather_analysis.sql
-- Витрина: погодные условия по гонкам

{{ config(
    materialized='table'
) }}

WITH race_sessions AS (

    SELECT
        session_key,
        year,
        circuit_short_name,
        country_name
    FROM {{ ref('stg_sessions') }}
    WHERE session_type = 'Race'
      AND session_name = 'Race'

),

weather_aggregated AS (

    SELECT
        session_key,

        ROUND(
            AVG(air_temperature)::numeric,
            2
        ) AS avg_air_temperature,

        ROUND(
            AVG(track_temperature)::numeric,
            2
        ) AS avg_track_temperature,

        ROUND(
            AVG(humidity)::numeric,
            2
        ) AS avg_humidity,

        ROUND(
            AVG(pressure)::numeric,
            2
        ) AS avg_pressure,

        ROUND(
            AVG(wind_speed)::numeric,
            2
        ) AS avg_wind_speed,

        BOOL_OR(rainfall) AS had_rain,

        COUNT(*) AS weather_measurements

    FROM {{ ref('stg_weather') }}

    GROUP BY
        session_key

)

SELECT
    rs.year,
    rs.circuit_short_name,
    rs.country_name,
    wa.avg_air_temperature,
    wa.avg_track_temperature,
    wa.avg_humidity,
    wa.avg_pressure,
    wa.avg_wind_speed,
    wa.had_rain,
    wa.weather_measurements

FROM race_sessions AS rs

INNER JOIN weather_aggregated AS wa
    ON rs.session_key = wa.session_key

ORDER BY
    rs.year DESC,
    rs.circuit_short_name