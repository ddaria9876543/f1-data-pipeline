-- mart_fastest_laps.sql
-- Витрина: самые быстрые круги пилотов по трассам

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

ranked_laps AS (

    SELECT
        l.session_key,
        l.driver_number,
        l.lap_number,
        l.lap_duration,
        l.duration_sector_1,
        l.duration_sector_2,
        l.duration_sector_3,
        rs.circuit_short_name,
        rs.country_name,
        rs.year,

        ROW_NUMBER() OVER (
            PARTITION BY
                l.driver_number,
                rs.circuit_short_name,
                rs.year
            ORDER BY
                l.lap_duration ASC,
                l.lap_number ASC
        ) AS lap_rank

    FROM {{ ref('stg_laps') }} AS l

    INNER JOIN race_sessions AS rs
        ON l.session_key = rs.session_key

),

fastest_per_driver AS (

    SELECT
        session_key,
        driver_number,
        lap_number,
        lap_duration AS fastest_lap_sec,
        duration_sector_1,
        duration_sector_2,
        duration_sector_3,
        circuit_short_name,
        country_name,
        year
    FROM ranked_laps
    WHERE lap_rank = 1

),

enriched_laps AS (

    SELECT
        fpd.driver_number,
        d.full_name AS driver_name,
        d.name_acronym AS name_acronym,
        d.team_name AS team_name,
        fpd.circuit_short_name,
        fpd.country_name,
        fpd.year,
        fpd.lap_number,
        fpd.fastest_lap_sec,
        fpd.duration_sector_1,
        fpd.duration_sector_2,
        fpd.duration_sector_3
    FROM fastest_per_driver AS fpd

    INNER JOIN {{ ref('stg_drivers') }} AS d
        ON fpd.session_key = d.session_key
       AND fpd.driver_number = d.driver_number

)

SELECT
    driver_number,
    driver_name,
    name_acronym,
    team_name,
    circuit_short_name,
    country_name,
    year,
    lap_number,
    fastest_lap_sec,
    duration_sector_1,
    duration_sector_2,
    duration_sector_3,

    CONCAT(
        FLOOR(fastest_lap_sec / 60)::integer::text,
        ':',
        LPAD(
            ROUND(
                MOD(fastest_lap_sec::numeric, 60),
                3
            )::text,
            6,
            '0'
        )
    ) AS fastest_lap_fmt,

    RANK() OVER (
        PARTITION BY
            circuit_short_name,
            year
        ORDER BY
            fastest_lap_sec ASC
    ) AS rank_on_circuit

FROM enriched_laps

ORDER BY
    year DESC,
    circuit_short_name,
    rank_on_circuit