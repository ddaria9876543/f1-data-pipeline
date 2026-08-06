-- stg_pit_stops.sql
-- Очистка и категоризация пит-стопов

{{ config(materialized='view') }}

WITH source_pit_stops AS (

    SELECT
        id,
        session_key,
        driver_number,
        lap_number,
        pit_duration,
        date
    FROM {{ source('f1_raw', 'pit_stops') }}

),

cleaned_pit_stops AS (

    SELECT
        id,
        session_key,
        driver_number,
        lap_number,
        pit_duration,
        date AS pit_stop_timestamp,

        CASE
            WHEN pit_duration < 5 THEN 'very_fast'
            WHEN pit_duration < 15 THEN 'normal'
            WHEN pit_duration < 60 THEN 'slow'
            ELSE 'very_slow'
        END AS pit_stop_category,

        ROW_NUMBER() OVER (
            PARTITION BY
                session_key,
                driver_number,
                lap_number,
                date
            ORDER BY id DESC
        ) AS row_num

    FROM source_pit_stops

    WHERE session_key IS NOT NULL
      AND driver_number IS NOT NULL
      AND lap_number IS NOT NULL
      AND lap_number > 0
      AND pit_duration IS NOT NULL
      AND pit_duration > 0
      AND pit_duration < 600
      AND date IS NOT NULL

)

SELECT
    id,
    session_key,
    driver_number,
    lap_number,
    pit_duration,
    pit_stop_timestamp,
    pit_stop_category
FROM cleaned_pit_stops
WHERE row_num = 1