-- mart_pit_stop_impact.sql
-- Витрина: влияние пит-стопов на итоговую позицию

{{ config(
    materialized='table'
) }}

WITH race_sessions AS (

    SELECT
        session_key,
        circuit_short_name,
        country_name,
        year
    FROM {{ ref('stg_sessions') }}
    WHERE session_type = 'Race'
      AND session_name = 'Race'

),

pit_counts AS (

    SELECT
        session_key,
        driver_number,
        COUNT(*) AS pit_stop_count,
        AVG(pit_duration) AS avg_pit_duration_sec,
        SUM(pit_duration) AS total_pit_time_sec
    FROM {{ ref('stg_pit_stops') }}
    WHERE pit_duration < 60
    GROUP BY
        session_key,
        driver_number

),

ranked_positions AS (

    SELECT
        session_key,
        driver_number,
        position,
        position_timestamp,

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

)

SELECT
    rs.year AS year,
    rs.circuit_short_name AS circuit_short_name,
    rs.country_name AS country_name,
    d.full_name AS driver_name,
    d.name_acronym AS name_acronym,
    d.team_name AS team_name,
    pc.pit_stop_count AS pit_stop_count,

    ROUND(
        pc.avg_pit_duration_sec::numeric,
        2
    ) AS avg_pit_duration_sec,

    ROUND(
        pc.total_pit_time_sec::numeric,
        2
    ) AS total_pit_time_sec,

    fp.final_position AS final_position

FROM pit_counts AS pc

INNER JOIN race_sessions AS rs
    ON pc.session_key = rs.session_key

INNER JOIN final_positions AS fp
    ON pc.session_key = fp.session_key
   AND pc.driver_number = fp.driver_number

INNER JOIN {{ ref('stg_drivers') }} AS d
    ON pc.session_key = d.session_key
   AND pc.driver_number = d.driver_number

ORDER BY
    year DESC,
    circuit_short_name,
    final_position