
-- Проверка дубликатов кругов
-- Один пилот не должен иметь два круга
-- с одинаковым номером в одной сессии

SELECT
    session_key,
    driver_number,
    lap_number,
    COUNT(*) AS duplicate_count
FROM {{ ref('stg_laps') }}
GROUP BY
    session_key,
    driver_number,
    lap_number
HAVING COUNT(*) > 1
