-- mart_driver_performance.sql
-- Витрина: результаты пилотов по сезонам и командам

{{ config(
    materialized='table'
) }}

WITH race_sessions AS (

    SELECT
        session_key,
        year
    FROM {{ ref('stg_sessions') }}
    WHERE session_type = 'Race'
      AND session_name = 'Race'

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

driver_lap_statistics AS (

    SELECT
        session_key,
        driver_number,
        AVG(lap_duration) AS avg_lap_sec,
        MIN(lap_duration) AS best_lap_sec
    FROM {{ ref('stg_laps') }}
    GROUP BY
        session_key,
        driver_number

),

driver_race_results AS (

    SELECT
        rs.year,
        rs.session_key,
        fp.driver_number,
        d.full_name,
        d.name_acronym,
        d.team_name,
        fp.final_position,
        dls.avg_lap_sec,
        dls.best_lap_sec

    FROM race_sessions AS rs

    INNER JOIN final_positions AS fp
        ON rs.session_key = fp.session_key

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON fp.session_key = d.session_key
       AND fp.driver_number = d.driver_number

    LEFT JOIN driver_lap_statistics AS dls
        ON fp.session_key = dls.session_key
       AND fp.driver_number = dls.driver_number

)

SELECT
    year,
    driver_number,
    full_name,
    name_acronym,
    team_name,

    COUNT(DISTINCT session_key) AS races,

    ROUND(
        AVG(final_position)::numeric,
        2
    ) AS avg_finish,

    COUNT(*) FILTER (
        WHERE final_position = 1
    ) AS wins,

    COUNT(*) FILTER (
        WHERE final_position <= 3
    ) AS podiums,

    COUNT(*) FILTER (
        WHERE final_position <= 10
    ) AS points_finishes,

    ROUND(
        AVG(avg_lap_sec)::numeric,
        3
    ) AS avg_lap_time,

    ROUND(
        MIN(best_lap_sec)::numeric,
        3
    ) AS best_lap

FROM driver_race_results

GROUP BY
    year,
    driver_number,
    full_name,
    name_acronym,
    team_name

ORDER BY
    year DESC,
    avg_finish ASC