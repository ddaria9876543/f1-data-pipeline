-- mart_team_comparison.sql
-- Витрина: сравнение команд по сезону

{{ config(
    materialized='table'
) }}

WITH race_sessions AS (

    SELECT
        session_key,
        circuit_short_name,
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

driver_race_results AS (

    SELECT
        rs.year AS year,
        fp.session_key AS session_key,
        fp.driver_number AS driver_number,
        d.team_name AS team_name,
        fp.final_position AS final_position
    FROM final_positions AS fp

    INNER JOIN race_sessions AS rs
        ON fp.session_key = rs.session_key

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON fp.session_key = d.session_key
       AND fp.driver_number = d.driver_number

),

driver_lap_statistics AS (

    SELECT
        rs.year AS year,
        l.session_key AS session_key,
        l.driver_number AS driver_number,
        d.team_name AS team_name,
        AVG(l.lap_duration) AS avg_lap_time_sec,
        MIN(l.lap_duration) AS best_lap_time_sec
    FROM {{ ref('stg_laps') }} AS l

    INNER JOIN race_sessions AS rs
        ON l.session_key = rs.session_key

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON l.session_key = d.session_key
       AND l.driver_number = d.driver_number

    GROUP BY
        rs.year,
        l.session_key,
        l.driver_number,
        d.team_name

),

team_results AS (

    SELECT
        year,
        team_name,
        COUNT(DISTINCT session_key) AS races_count,
        AVG(final_position) AS avg_position,
        COUNT(*) FILTER (
            WHERE final_position = 1
        ) AS wins,
        COUNT(*) FILTER (
            WHERE final_position <= 3
        ) AS podiums,
        COUNT(*) FILTER (
            WHERE final_position <= 10
        ) AS points_finishes
    FROM driver_race_results

    GROUP BY
        year,
        team_name

),

team_lap_statistics AS (

    SELECT
        year,
        team_name,
        AVG(avg_lap_time_sec) AS avg_lap_time_sec,
        MIN(best_lap_time_sec) AS best_lap_time_sec
    FROM driver_lap_statistics

    GROUP BY
        year,
        team_name

)

SELECT
    tr.year AS year,
    tr.team_name AS team_name,
    tr.races_count AS races_count,

    ROUND(
        tr.avg_position::numeric,
        2
    ) AS avg_position,

    tr.wins AS wins,
    tr.podiums AS podiums,
    tr.points_finishes AS points_finishes,

    ROUND(
        tls.avg_lap_time_sec::numeric,
        3
    ) AS avg_lap_time_sec,

    ROUND(
        tls.best_lap_time_sec::numeric,
        3
    ) AS best_lap_time_sec

FROM team_results AS tr

LEFT JOIN team_lap_statistics AS tls
    ON tr.year = tls.year
   AND tr.team_name = tls.team_name

ORDER BY
    year DESC,
    avg_position ASC