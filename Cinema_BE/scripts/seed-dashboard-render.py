"""Generate dated showtimes and synthetic cash sales in a Cinema demo database."""
import argparse
from datetime import datetime, time, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess
from urllib.parse import parse_qs, unquote, urlsplit


DATABASES = ("MOVIE", "SHOWTIME", "BOOKING", "PAYMENT")
VIETNAM = timezone(timedelta(hours=7))


def sql_json(value):
    return "'" + json.dumps(value, ensure_ascii=False).replace("'", "''") + "'::json"


def rows(name, query):
    return f"SELECT COALESCE(json_agg({name}), '[]') FROM ({query}) AS {name};"


def connect(name):
    variable = f"CINEMA_DEMO_{name}_URL"
    url = urlsplit(os.environ.get(variable, ""))
    if url.scheme not in ("postgres", "postgresql") or not url.hostname or not url.username or not url.path[1:]:
        raise ValueError(f"Set {variable} to the PostgreSQL URL for the {name.lower()} database.")
    sslmode = parse_qs(url.query).get("sslmode", ["require"])[0]
    if sslmode not in ("require", "verify-ca", "verify-full") and not (
        url.hostname in ("localhost", "127.0.0.1", "::1") and sslmode == "disable"
    ):
        raise ValueError(f"{variable} must use TLS outside localhost.")
    env = {key: value for key, value in os.environ.items() if not key.startswith("PG")}
    env.update(PGHOST=url.hostname, PGPORT=str(url.port or 5432), PGDATABASE=unquote(url.path[1:]),
               PGUSER=unquote(url.username), PGPASSWORD=unquote(url.password or ""), PGSSLMODE=sslmode,
               PGCLIENTENCODING="UTF8", PGCONNECT_TIMEOUT="10")
    return env


def query(env, statement):
    result = subprocess.run(
        ["psql", "-XqAtw", "-v", "ON_ERROR_STOP=1"],
        input="SET lock_timeout = '5s'; SET standard_conforming_strings = on;\n" + statement,
        env=env, encoding="utf-8",
        capture_output=True, check=False, timeout=60,
    )
    if result.returncode:
        raise RuntimeError(f"{env['PGDATABASE']}: {result.stderr.strip()}")
    return json.loads(result.stdout) if result.stdout.strip() else None


def plan_shows(movies, rooms, schedule, now):
    today = now.date()
    planned = []
    for offset in range(-6, 7):
        historical = offset < 0
        date = today + timedelta(days=offset)
        for slot, preferred in enumerate((10, 15) if historical else (13, 16, 19)):
            movie = movies[(3 * (offset + 6) + slot) % len(movies)]
            duration = timedelta(minutes=movie["duration_minutes"])
            times = [datetime.combine(date, time(hour)) for hour in range(8, 23)]
            times.sort(key=lambda start: abs(start.hour - preferred))
            for start in times:
                end = start + duration
                if not historical and start <= now + timedelta(minutes=20):
                    continue
                room = next((room_id for room_id in rooms if all(
                    item["room_id"] != room_id or item["status"] == "CANCELLED"
                    or datetime.fromisoformat(item["end_time"]) <= start
                    or datetime.fromisoformat(item["start_time"]) >= end
                    for item in schedule + planned
                )), None)
                if room is not None:
                    planned.append(dict(movie_id=movie["id"], title=movie["title"], room_id=room,
                                        start_time=start.isoformat(), end_time=end.isoformat(),
                                        status="CLOSED" if historical else "OPEN",
                                        price=85000 + 5000 * ((slot + offset) % 4)))
                    break
            else:
                if offset != 0:
                    raise ValueError(f"No free room for demo slot {slot + 1} on {date}.")
    return planned


def order_rows(shows, seats, now):
    today = now.date()
    history = [show for show in shows if show["status"] == "CLOSED"]
    future = min((show for show in shows if show["status"] == "OPEN"), key=lambda show: show["start_time"])
    orders, tickets = [], []
    for offset in range(-6, 1):
        day = today + timedelta(days=offset)
        day_shows = [show for show in history if show["start_time"][:10] == str(day)] if offset < 0 else [future]
        for slot, show in enumerate(day_shows):
            start = datetime.fromisoformat(show["start_time"])
            created = start - timedelta(minutes=30) if offset < 0 else now
            available = seats[show["room_id"]]
            count = 2 + (offset + slot) % 3
            scenarios = [("CONFIRMED", 1 + index % 2) for index in range(count)] + [("CANCELLED", 1)]
            if offset == 0 and start.date() == today:
                scenarios.append(("PENDING", 3))
            cursor = 0
            for index, (status, seat_count) in enumerate(scenarios):
                code = f"DEMO-DASH7-{today:%Y%m%d}-{offset + 6}-{slot}-{index}"
                orders.append(dict(code=code, showtime_id=show["id"], title=show["title"],
                                   show_time=show["start_time"], created_at=created.isoformat(),
                                   checked_in_at=(start - timedelta(minutes=5)).isoformat()
                                   if offset < 0 and status == "CONFIRMED" else None,
                                   expires_at=(created + timedelta(minutes=10)).isoformat()
                                   if status == "PENDING" else None, status=status,
                                   amount=seat_count * show["price"]))
                for seat in available[cursor:cursor + seat_count]:
                    tickets.append(dict(code=code, seat_id=seat["id"],
                                        label=f"{seat['seat_row']}{seat['seat_number']}", price=show["price"]))
                cursor += seat_count
    return orders, tickets


def seed(envs, plan):
    showtimes = envs["SHOWTIME"]
    shows, orders, seats = (plan[key] for key in ("shows", "orders", "tickets"))
    show_records = ("id bigint,movie_id bigint,room_id bigint,start_time timestamp,end_time timestamp,"
                    "status text,price numeric")
    query(showtimes, f"""
        BEGIN;
        LOCK TABLE showtimes IN SHARE ROW EXCLUSIVE MODE;
        CREATE TEMP TABLE fixture AS SELECT * FROM json_to_recordset({sql_json(shows)}) AS s({show_records});
        DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM fixture f JOIN showtimes s ON s.room_id=f.room_id
              AND s.id<>f.id AND s.status<>'CANCELLED' AND s.start_time<f.end_time AND s.end_time>f.start_time)
          THEN RAISE EXCEPTION 'A demo slot now overlaps an existing showtime'; END IF;
          IF EXISTS (SELECT 1 FROM fixture f JOIN showtimes s USING (id)
              WHERE (s.movie_id,s.room_id,s.start_time,s.end_time,s.price,s.status,s.format)
                  IS DISTINCT FROM (f.movie_id,f.room_id,f.start_time,f.end_time,f.price,f.status,'2D'::varchar))
          THEN RAISE EXCEPTION 'A recorded demo showtime has changed'; END IF;
        END $$;
        INSERT INTO showtimes(id,movie_id,room_id,start_time,end_time,status,price,format)
          SELECT id,movie_id,room_id,start_time,end_time,status,price,'2D' FROM fixture
          ON CONFLICT(id) DO NOTHING;
        COMMIT;
    """)
    bookings = envs["BOOKING"]
    booking_ids = query(bookings, f"""
        BEGIN;
        LOCK TABLE bookings, booking_seats, seat_reservations IN SHARE ROW EXCLUSIVE MODE;
        CREATE TEMP TABLE fixture AS SELECT * FROM json_to_recordset({sql_json(orders)}) AS o(
          code text,showtime_id bigint,title text,show_time timestamp,created_at timestamp,
          checked_in_at timestamp,expires_at timestamp,status text,amount numeric);
        INSERT INTO bookings(booking_code,showtime_id,movie_title,show_time,created_at,checked_in_at,expires_at,status,total_amount)
          SELECT code,showtime_id,title,show_time,created_at,checked_in_at,expires_at,status,amount FROM fixture
          ON CONFLICT(booking_code) DO NOTHING;
        DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM fixture f JOIN bookings b ON b.booking_code=f.code
              WHERE (b.showtime_id,b.created_at,b.total_amount)
                  IS DISTINCT FROM (f.showtime_id,f.created_at,f.amount)
                 OR (b.status<>f.status AND NOT (f.status='PENDING' AND b.status='EXPIRED')))
          THEN RAISE EXCEPTION 'A recorded demo booking has changed'; END IF;
        END $$;
        INSERT INTO booking_seats(booking_id,seat_id,seat_label,price)
          SELECT b.id,s.seat_id,s.label,s.price
          FROM json_to_recordset({sql_json(seats)}) AS s(code text,seat_id bigint,label text,price numeric)
          JOIN bookings b ON b.booking_code=s.code
          WHERE NOT EXISTS (SELECT 1 FROM booking_seats bs WHERE bs.booking_id=b.id AND bs.seat_id=s.seat_id);
        CREATE TEMP VIEW active_fixture_seats AS
          SELECT b.id AS booking_id,b.showtime_id,bs.seat_id,
                 CASE WHEN b.status='PENDING' THEN 'HELD' ELSE 'BOOKED' END AS status,
                 b.expires_at AS held_until
          FROM bookings b JOIN booking_seats bs ON bs.booking_id=b.id
          JOIN fixture f ON b.booking_code=f.code
          WHERE b.status='CONFIRMED' OR (b.status='PENDING' AND b.expires_at>CURRENT_TIMESTAMP AT TIME ZONE 'Asia/Ho_Chi_Minh');
        INSERT INTO seat_reservations(showtime_id,seat_id,status,held_until,booking_id)
          SELECT showtime_id,seat_id,status,held_until,booking_id FROM active_fixture_seats
          ON CONFLICT(showtime_id,seat_id) DO NOTHING;
        DO $$ BEGIN
          IF EXISTS (SELECT 1 FROM active_fixture_seats f
              LEFT JOIN seat_reservations sr ON sr.showtime_id=f.showtime_id AND sr.seat_id=f.seat_id
              WHERE (sr.booking_id,sr.status) IS DISTINCT FROM (f.booking_id,f.status))
          THEN RAISE EXCEPTION 'A demo seat is already reserved by another booking'; END IF;
        END $$;
        SELECT json_object_agg(b.booking_code,b.id) FROM bookings b JOIN fixture f ON b.booking_code=f.code;
        COMMIT;
    """)
    payments = [dict(code="PAY-" + order["code"], booking_id=booking_ids[order["code"]],
                     amount=order["amount"], created_at=order["created_at"])
                for order in orders if order["status"] == "CONFIRMED"]
    payment_ids = query(envs["PAYMENT"], f"""
        BEGIN;
        CREATE TEMP TABLE fixture AS SELECT * FROM json_to_recordset({sql_json(payments)})
          AS p(code text,booking_id bigint,amount numeric,created_at timestamp);
        INSERT INTO payments(payment_code,booking_id,amount,created_at,updated_at,method,status)
          SELECT code,booking_id,amount,created_at,created_at,'CASH','SUCCESS' FROM fixture
          ON CONFLICT(payment_code) DO NOTHING;
        SELECT json_object_agg(p.booking_id,p.id) FROM payments p
          JOIN fixture f ON p.payment_code=f.code AND p.booking_id=f.booking_id AND p.amount=f.amount
            AND p.created_at=f.created_at AND p.method='CASH' AND p.status='SUCCESS';
        COMMIT;
    """)
    if len(payment_ids or {}) != len(payments):
        raise ValueError("Existing payment data differs from the demo plan.")
    links = [dict(booking_id=key, payment_id=value) for key, value in payment_ids.items()]
    linked = query(bookings, f"""
        BEGIN;
        CREATE TEMP TABLE fixture AS SELECT * FROM json_to_recordset({sql_json(links)})
          AS l(booking_id bigint,payment_id bigint);
        UPDATE bookings b SET payment_id=f.payment_id FROM fixture f
          WHERE b.id=f.booking_id AND b.payment_id IS NULL AND b.booking_code LIKE 'DEMO-DASH7-%';
        SELECT count(*) FROM bookings b JOIN fixture f ON b.id=f.booking_id AND b.payment_id=f.payment_id;
        COMMIT;
    """)
    if linked != len(payments):
        raise ValueError("One or more demo bookings reference a different payment.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Write the fixture into the configured demo databases.")
    parser.add_argument("--state-dir", type=Path, default=Path.home() / ".cinema-demo",
                        help="Folder for the saved plan used to resume or repeat a run.")
    args = parser.parse_args()
    envs = {name: connect(name) for name in DATABASES}
    targets = [tuple(env[key] for key in ("PGHOST", "PGPORT", "PGDATABASE")) for env in envs.values()]
    if len(set(targets)) != len(DATABASES):
        raise ValueError("Movie, showtime, booking and payment must target distinct logical databases.")
    now = datetime.now(VIETNAM).replace(tzinfo=None, microsecond=0)
    fingerprint = hashlib.sha256(json.dumps(targets).encode()).hexdigest()[:12]
    state_file = args.state_dir / f"dashboard-{fingerprint}-{now.date()}.json"

    # Check the schema on all targets before reserving IDs or writing fixtures.
    for table in ("bookings", "booking_seats", "seat_reservations"):
        query(envs["BOOKING"], f"SELECT count(*) FROM {table} WHERE false;")
    query(envs["PAYMENT"], "SELECT count(booking_id) FROM payments WHERE false;")
    if state_file.exists():
        plan = json.loads(state_file.read_text(encoding="utf-8"))
    else:
        if query(envs["BOOKING"], f"""
            SELECT count(*) FROM bookings WHERE booking_code LIKE 'DEMO-DASH7-{now:%Y%m%d}-%';
        """):
            raise ValueError(f"Today's demo data already exists. Use the original state file: {state_file}")
        movies = query(envs["MOVIE"], rows("movie", f"""
            SELECT id,title,duration_minutes FROM movies WHERE status='ACTIVE'
              AND duration_minutes BETWEEN 1 AND 210
              AND (release_date IS NULL OR release_date<='{now.date()}')
            ORDER BY id
        """))
        room_seats = query(envs["SHOWTIME"], rows("seat", """
            SELECT s.id,s.room_id,s.seat_row,s.seat_number FROM seats s JOIN rooms r ON r.id=s.room_id
              WHERE s.seat_type='NORMAL' ORDER BY s.room_id,s.id
        """))
        seats = {}
        for seat in room_seats:
            seats.setdefault(seat["room_id"], []).append(seat)
        rooms = [room_id for room_id, room in seats.items() if len(room) >= 10]
        if not movies or not rooms:
            raise ValueError("Load active movies and at least one room with 10 normal seats first.")
        first = now.date() - timedelta(days=6)
        last = now.date() + timedelta(days=8)
        schedule = query(envs["SHOWTIME"], rows("show", f"""
            SELECT room_id,start_time,end_time,status FROM showtimes
              WHERE end_time > '{first}' AND start_time < '{last}'
        """))
        shows = plan_shows(movies, rooms, schedule, now)
        if args.apply:
            ids = query(envs["SHOWTIME"], f"""
                SELECT json_agg(nextval(pg_get_serial_sequence('showtimes','id')))
                FROM generate_series(1,{len(shows)});
            """)
            if any(not isinstance(show_id, int) for show_id in ids) or len(set(ids)) != len(shows):
                raise ValueError("Could not reserve unique showtime IDs.")
        else:
            ids = range(1, len(shows) + 1)
        for show, show_id in zip(shows, ids):
            show["id"] = show_id
        orders, tickets = order_rows(shows, seats, now)
        plan = dict(shows=shows, orders=orders, tickets=tickets)
        if args.apply:
            args.state_dir.mkdir(parents=True, exist_ok=True)
            temporary = state_file.with_suffix(".tmp")
            temporary.write_text(json.dumps(plan, ensure_ascii=False, indent=2), encoding="utf-8")
            temporary.replace(state_file)

    if args.apply:
        seed(envs, plan)
    paid = [order for order in plan["orders"] if order["status"] == "CONFIRMED"]
    held = {order["code"] for order in plan["orders"] if order["status"] == "PENDING"
            and datetime.fromisoformat(order["expires_at"]) > now}
    print(json.dumps(dict(mode="applied" if args.apply else "preview", date=str(now.date()),
                          open_showtimes=sum(show["status"] == "OPEN" for show in plan["shows"]),
                          historical_showtimes=sum(show["status"] == "CLOSED" for show in plan["shows"]),
                          bookings=len(plan["orders"]), cash_payments=len(paid),
                          held_seats=sum(ticket["code"] in held for ticket in plan["tickets"]),
                          revenue_vnd=sum(order["amount"] for order in paid),
                          state=str(state_file) if args.apply else None)))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        raise SystemExit(f"Seed failed: {error}") from None
