#!/bin/sh
set -eu

# Only schema migrations belong here; demo schedules and coming-soon seeds are opt-in.
for file in /db-scripts/migrations/*.sql; do
    name=$(basename "$file")
    case "$name" in
        *showtime_schedule*|*more_daily*|*extra_morning*|*distinct_room*|*coming_soon*) continue ;;
    esac
    case "$name" in
        *_cinema_auth_*) db=auth ;;
        *_cinema_booking_*) db=booking ;;
        *_cinema_movie_*) db=movie ;;
        *_cinema_showtime_*) db=showtime ;;
        *_cinema_payment_*) db=payment ;;
        *_cinema_notification_*) db=notification ;;
        *) echo "Unknown migration database: $name" >&2; exit 1 ;;
    esac
    echo "==> $name"
    psql -X -v ON_ERROR_STOP=1 -d "cinema_${db}_db" -f "$file"
done

for file in /schema-fixes/*.sql; do
    psql -X -v ON_ERROR_STOP=1 -d postgres -f "$file"
done
