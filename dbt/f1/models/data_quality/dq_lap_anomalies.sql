{{ config(
    materialized='table'
) }}

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

classified_laps AS (

    SELECT
        *,
        CASE
            WHEN session_key IS NULL
                THEN 'missing_session_key'

            WHEN driver_number IS NULL
                THEN 'missing_driver_number'

            WHEN lap_number IS NULL
                THEN 'missing_lap_number'

            WHEN lap_duration IS NULL
                THEN 'missing_lap_duration'

            WHEN lap_duration <= 0
                THEN 'non_positive_lap_duration'

            WHEN lap_duration < 60
                THEN 'lap_too_short'

            WHEN lap_duration > 300
                THEN 'lap_too_long'

            WHEN COALESCE(is_pit_out_lap, false) = true
                THEN 'pit_out_lap'

            ELSE NULL
        END AS anomaly_reason

    FROM source_laps

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
    date_start,
    anomaly_reason
FROM classified_laps
WHERE anomaly_reason IS NOT NULL