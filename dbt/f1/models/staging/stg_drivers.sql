-- stg_drivers.sql
-- Очистка и дедупликация пилотов внутри каждой сессии

{{ config(materialized='view') }}

WITH source_drivers AS (

    SELECT
        session_key,
        driver_number,
        full_name,
        name_acronym,
        team_name,
        team_colour,
        country_code
    FROM {{ source('f1_raw', 'drivers') }}

),

cleaned_drivers AS (

    SELECT
        session_key,
        driver_number,
        TRIM(full_name) AS full_name,
        TRIM(name_acronym) AS name_acronym,
        TRIM(team_name) AS team_name,
        TRIM(team_colour) AS team_colour,
        TRIM(country_code) AS country_code,

        ROW_NUMBER() OVER (
            PARTITION BY session_key, driver_number
            ORDER BY driver_number
        ) AS row_num

    FROM source_drivers

    WHERE session_key IS NOT NULL
      AND driver_number IS NOT NULL
      AND full_name IS NOT NULL
      AND TRIM(full_name) <> ''
      AND team_name IS NOT NULL
      AND TRIM(team_name) <> ''

)

SELECT
    session_key,
    driver_number,
    full_name,
    name_acronym,
    team_name,
    team_colour,
    country_code
FROM cleaned_drivers
WHERE row_num = 1