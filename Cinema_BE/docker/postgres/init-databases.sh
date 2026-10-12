#!/bin/sh
# Tu dong chay MOT LAN khi volume du lieu PostgreSQL con trong (lan "docker compose up" dau tien).
# Tao 6 database va nap file SQL cua repo Project-Cinema-DB (duoc mount vao /db-scripts).
set -e

for db in auth movie showtime booking payment notification; do
    file="/db-scripts/cinema_${db}_db.sql"
    if [ ! -f "$file" ]; then
        echo "Khong tim thay $file - kiem tra DB_SCRIPTS_DIR trong .env (mac dinh ../../Project-Cinema-DB, canh thu muc Cinema)" >&2
        exit 1
    fi

    echo "==> Tao cinema_${db}_db"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres -c "CREATE DATABASE cinema_${db}_db;"
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cinema_${db}_db" -f "$file" > /dev/null

    # File seed chen id co dinh nen sequence chua duoc day len -> dong bo lai de insert moi khong trung id
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "cinema_${db}_db" -q <<'SQL'
DO $$
DECLARE r record;
BEGIN
    FOR r IN
        SELECT table_name, column_name,
               pg_get_serial_sequence(format('%I', table_name), column_name) AS seq
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND pg_get_serial_sequence(format('%I', table_name), column_name) IS NOT NULL
    LOOP
        EXECUTE format('SELECT setval(%L, COALESCE((SELECT MAX(%I) FROM %I), 0) + 1, false)',
                       r.seq, r.column_name, r.table_name);
    END LOOP;
END $$;
SQL
done

echo "==> Them lich chieu demo cho mot thang"
# Lich chieu demo nam trong repo Project-Cinema-DB moi: thieu file thi bo qua, DB van tao duoc
for migration in 2026-10-10_cinema_more_daily_showtimes.sql 2026-10-10_cinema_distinct_room_layouts.sql; do
    file="/db-scripts/migrations/$migration"
    if [ ! -f "$file" ]; then
        echo "Bo qua $migration: chua co trong Project-Cinema-DB (git pull repo DB, roi docker compose down -v va up lai)" >&2
        continue
    fi
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname cinema_showtime_db -f "$file" > /dev/null
done

echo "==> Da tao xong 6 database"
