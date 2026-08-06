-- stg_weather.sql
-- Очистка и обогащение погодных данных

{{ config(materialized='view') }}

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

cleaned_weather AS (

    SELECT
        id,
        session_key,
        date AS weather_timestamp,
        air_temperature,
        track_temperature,
        humidity,
        pressure,
        wind_speed,
        wind_direction,
        COALESCE(rainfall, false) AS rainfall,

        track_temperature - air_temperature
            AS temperature_difference,

        CASE
            WHEN COALESCE(rainfall, false) = true
                THEN 'rainy'
            WHEN track_temperature >= 40
                THEN 'hot_track'
            WHEN air_temperature <= 10
                THEN 'cold'
            ELSE 'normal'
        END AS weather_condition,

        ROW_NUMBER() OVER (
            PARTITION BY session_key, date
            ORDER BY id DESC
        ) AS row_num

    FROM source_weather

    WHERE session_key IS NOT NULL
      AND date IS NOT NULL
      AND air_temperature IS NOT NULL
      AND air_temperature BETWEEN -20 AND 60
      AND track_temperature IS NOT NULL
      AND track_temperature BETWEEN -20 AND 90
      AND humidity IS NOT NULL
      AND humidity BETWEEN 0 AND 100
      AND pressure IS NOT NULL
      AND pressure BETWEEN 700 AND 1100
      AND wind_speed IS NOT NULL
      AND wind_speed BETWEEN 0 AND 100
      AND (
          wind_direction IS NULL
          OR wind_direction BETWEEN 0 AND 359
      )

)

SELECT
    id,
    session_key,
    weather_timestamp,
    air_temperature,
    track_temperature,
    humidity,
    pressure,
    wind_speed,
    wind_direction,
    rainfall,
    temperature_difference,
    weather_condition
FROM cleaned_weather
WHERE row_num = 1