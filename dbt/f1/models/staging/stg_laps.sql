-- stg_laps.sql
-- Очистка данных о кругах

{{ config(materialized='view') }}

WITH source_laps AS (

    SELECT
        session_key,
        driver_number,
        lap_number,
        lap_duration,
        duration_sector_1,
        duration_sector_2,
        duration_sector_3,
        i1_speed,
        i2_speed,
        st_speed,
        is_pit_out_lap,
        date_start
    FROM {{ source('f1_raw', 'laps') }}

),

cleaned_laps AS (

    SELECT
        session_key,
        driver_number,
        lap_number,
        lap_duration,
        duration_sector_1,
        duration_sector_2,
        duration_sector_3,
        i1_speed,
        i2_speed,
        st_speed,
        COALESCE(is_pit_out_lap, false) AS is_pit_out_lap,
        date_start,

        ROW_NUMBER() OVER (
            PARTITION BY
                session_key,
                driver_number,
                lap_number
            ORDER BY date_start DESC NULLS LAST
        ) AS row_num

    FROM source_laps

    WHERE session_key IS NOT NULL
      AND driver_number IS NOT NULL
      AND lap_number IS NOT NULL
      AND lap_duration IS NOT NULL
      AND lap_duration > 60
      AND lap_duration < 300
      AND COALESCE(is_pit_out_lap, false) = false

)

SELECT
    session_key,
    driver_number,
    lap_number,
    lap_duration,
    duration_sector_1,
    duration_sector_2,
    duration_sector_3,
    i1_speed,
    i2_speed,
    st_speed,
    is_pit_out_lap,
    date_start
FROM cleaned_laps
WHERE row_num = 1