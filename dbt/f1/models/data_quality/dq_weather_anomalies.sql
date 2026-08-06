{{ config(
    materialized='table'
) }}

WITH source_weather AS (

    SELECT
        id,
        session_key,
        date,
        air_temperature,
        track_temperature,
        humidity,
        pressure,
        wind_speed,
        wind_direction,
        rainfall
    FROM {{ source('f1_raw', 'weather') }}

),

classified_weather AS (

    SELECT
        *,
        CASE
            WHEN session_key IS NULL
                THEN 'missing_session_key'

            WHEN date IS NULL
                THEN 'missing_timestamp'

            WHEN air_temperature IS NULL
                THEN 'missing_air_temperature'

            WHEN air_temperature < -20
                OR air_temperature > 60
                THEN 'invalid_air_temperature'

            WHEN track_temperature IS NULL
                THEN 'missing_track_temperature'

            WHEN track_temperature < -20
                OR track_temperature > 90
                THEN 'invalid_track_temperature'

            WHEN humidity IS NULL
                THEN 'missing_humidity'

            WHEN humidity < 0
                OR humidity > 100
                THEN 'invalid_humidity'

            WHEN pressure IS NULL
                THEN 'missing_pressure'

            WHEN pressure < 800
                OR pressure > 1100
                THEN 'invalid_pressure'

            WHEN wind_speed IS NULL
                THEN 'missing_wind_speed'

            WHEN wind_speed < 0
                OR wind_speed > 100
                THEN 'invalid_wind_speed'

            WHEN wind_direction IS NOT NULL
                AND (
                    wind_direction < 0
                    OR wind_direction > 359
                )
                THEN 'invalid_wind_direction'

            ELSE NULL
        END AS anomaly_reason

    FROM source_weather

)

SELECT
    id,
    session_key,
    date,
    air_temperature,
    track_temperature,
    humidity,
    pressure,
    wind_speed,
    wind_direction,
    rainfall,
    anomaly_reason
FROM classified_weather
WHERE anomaly_reason IS NOT NULL