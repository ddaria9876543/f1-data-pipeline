$tables = @(
    "CREATE TABLE IF NOT EXISTS f1_analytics.sessions (session_key Int32, session_name String, session_type String, date_start Nullable(DateTime64(6, 'UTC')), date_end Nullable(DateTime64(6, 'UTC')), gmt_offset String, location String, country_name String, country_code String, circuit_key Nullable(Int32), circuit_short_name String, year Nullable(Int32)) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'sessions', 'postgres', 'f1pass123')",
    "CREATE TABLE IF NOT EXISTS f1_analytics.drivers (driver_number Int32, session_key Int32, broadcast_name String, full_name String, name_acronym String, team_name String, team_colour String, country_code String, headshot_url String) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'drivers', 'postgres', 'f1pass123')",
    "CREATE TABLE IF NOT EXISTS f1_analytics.laps (id Int32, session_key Int32, driver_number Int32, lap_number Nullable(Int32), lap_duration Nullable(Float64), duration_sector_1 Nullable(Float64), duration_sector_2 Nullable(Float64), duration_sector_3 Nullable(Float64), i1_speed Nullable(Float64), i2_speed Nullable(Float64), st_speed Nullable(Float64), is_pit_out_lap Nullable(Bool), date_start Nullable(DateTime64(6, 'UTC'))) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'laps', 'postgres', 'f1pass123')",
    "CREATE TABLE IF NOT EXISTS f1_analytics.pit_stops (id Int32, session_key Int32, driver_number Int32, lap_number Nullable(Int32), pit_duration Nullable(Float64), date Nullable(DateTime64(6, 'UTC'))) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'pit_stops', 'postgres', 'f1pass123')",
    "CREATE TABLE IF NOT EXISTS f1_analytics.weather (id Int32, session_key Int32, date Nullable(DateTime64(6, 'UTC')), air_temperature Nullable(Float64), track_temperature Nullable(Float64), humidity Nullable(Float64), pressure Nullable(Float64), wind_speed Nullable(Float64), wind_direction Nullable(Int32), rainfall Nullable(Bool)) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'weather', 'postgres', 'f1pass123')",
    "CREATE TABLE IF NOT EXISTS f1_analytics.positions (id Int32, session_key Int32, driver_number Int32, date Nullable(DateTime64(6, 'UTC')), position Nullable(Int32)) ENGINE = PostgreSQL('postgres-subscriber:5432', 'f1_replica', 'positions', 'postgres', 'f1pass123')"
)

foreach ($query in $tables) {
    Write-Host "Создаём таблицу..."
    echo $query | docker exec -i f1_clickhouse clickhouse-client -u f1user --password f1pass123
}

Write-Host "Готово! Проверяем таблицы:"
docker exec -it f1_clickhouse clickhouse-client -u f1user --password f1pass123 --query "SHOW TABLES FROM f1_analytics;"
