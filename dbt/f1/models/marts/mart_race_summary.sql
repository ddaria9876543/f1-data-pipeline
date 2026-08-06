-- mart_race_summary.sql
-- Сводная витрина: одна строка = одна гонка

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
        AND session_key IN (
            SELECT DISTINCT session_key
            FROM {{ ref('stg_positions') }}
        )

),

ranked_positions AS (

    SELECT
        session_key,
        driver_number,
        position,

        ROW_NUMBER() OVER (
            PARTITION BY
                session_key,
                driver_number
            ORDER BY
                position_timestamp DESC
        ) AS position_rank

    FROM {{ ref('stg_positions') }}

),

final_positions AS (

    SELECT
        session_key,
        driver_number,
        position AS final_position
    FROM ranked_positions
    WHERE position_rank = 1

),

winners AS (

    SELECT
        fp.session_key,
        fp.driver_number,
        d.full_name AS winner_name,
        d.name_acronym AS winner_acronym,
        d.team_name AS winner_team

    FROM final_positions AS fp

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON fp.session_key = d.session_key
       AND fp.driver_number = d.driver_number

    WHERE fp.final_position = 1

),

ranked_fastest_laps AS (

    SELECT
        l.session_key,
        l.driver_number,
        l.lap_number,
        l.lap_duration,

        ROW_NUMBER() OVER (
            PARTITION BY l.session_key
            ORDER BY
                l.lap_duration ASC,
                l.lap_number ASC
        ) AS lap_rank

    FROM {{ ref('stg_laps') }} AS l

),

fastest_laps AS (

    SELECT
        rfl.session_key,
        rfl.driver_number,
        d.full_name AS fastest_lap_driver,
        d.team_name AS fastest_lap_team,
        rfl.lap_number AS fastest_lap_number,

        ROUND(
            rfl.lap_duration::numeric,
            3
        ) AS fastest_lap_sec

    FROM ranked_fastest_laps AS rfl

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON rfl.session_key = d.session_key
       AND rfl.driver_number = d.driver_number

    WHERE rfl.lap_rank = 1

),

pit_stop_statistics AS (

    SELECT
        session_key,

        COUNT(*) AS total_pit_stops,

        COUNT(DISTINCT driver_number) AS drivers_with_pit_stops,

        ROUND(
            AVG(pit_duration)::numeric,
            2
        ) AS avg_pit_duration_sec,

        ROUND(
            MIN(pit_duration)::numeric,
            2
        ) AS fastest_pit_stop_sec,

        ROUND(
            MAX(pit_duration)::numeric,
            2
        ) AS slowest_pit_stop_sec

    FROM {{ ref('stg_pit_stops') }}

    WHERE pit_duration < 60

    GROUP BY
        session_key

),

weather_statistics AS (

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

        BOOL_OR(rainfall) AS had_rain

    FROM {{ ref('stg_weather') }}

    GROUP BY
        session_key

)

SELECT
    rs.session_key,
    rs.year,
    rs.circuit_short_name,
    rs.country_name,

    w.winner_name,
    w.winner_acronym,
    w.winner_team,

    fl.fastest_lap_driver,
    fl.fastest_lap_team,
    fl.fastest_lap_number,
    fl.fastest_lap_sec,

    COALESCE(ps.total_pit_stops, 0) AS total_pit_stops,
    COALESCE(ps.drivers_with_pit_stops, 0) AS drivers_with_pit_stops,
    ps.avg_pit_duration_sec,
    ps.fastest_pit_stop_sec,
    ps.slowest_pit_stop_sec,

    ws.avg_air_temperature,
    ws.avg_track_temperature,
    ws.avg_humidity,
    ws.avg_pressure,
    ws.avg_wind_speed,
    ws.had_rain

FROM race_sessions AS rs

LEFT JOIN winners AS w
    ON rs.session_key = w.session_key

LEFT JOIN fastest_laps AS fl
    ON rs.session_key = fl.session_key

LEFT JOIN pit_stop_statistics AS ps
    ON rs.session_key = ps.session_key

LEFT JOIN weather_statistics AS ws
    ON rs.session_key = ws.session_key

ORDER BY
    rs.year DESC,
    rs.circuit_short_name