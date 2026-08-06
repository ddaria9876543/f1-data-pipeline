-- stg_positions.sql
-- Очистка истории позиций пилотов

{{ config(materialized='view') }}

WITH source_positions AS (

    SELECT
        id,
        session_key,
        driver_number,
        date,
        position
    FROM {{ source('f1_raw', 'positions') }}

),

cleaned_positions AS (

    SELECT
        id,
        session_key,
        driver_number,
        date AS position_timestamp,
        position,

        ROW_NUMBER() OVER (
            PARTITION BY
                session_key,
                driver_number,
                date
            ORDER BY id DESC
        ) AS row_num

    FROM source_positions

    WHERE session_key IS NOT NULL
      AND driver_number IS NOT NULL
      AND date IS NOT NULL
      AND position IS NOT NULL
      AND position > 0
      AND position <= 30

)

SELECT
    id,
    session_key,
    driver_number,
    position_timestamp,
    position
FROM cleaned_positions
WHERE row_num = 1