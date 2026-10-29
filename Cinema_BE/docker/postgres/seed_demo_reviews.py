"""Opt-in local demo data: 10 customers, checked-in demo tickets and reviews.

Run with Python 3 while the Cinema Docker Compose stack is running.
Accounts: review.customer01@example.com through review.customer10@example.com.
Demo password: 123456. Only generated names and untouched [Demo] reviews are refreshed.
"""
import json
import pathlib
import subprocess

from review_samples import REVIEWER_NAMES, review_comment

ROOT = pathlib.Path(__file__).resolve().parents[2]


def sql(database, statement):
    result = subprocess.run(
        ["docker", "compose", "exec", "-T", "-e", "PGCLIENTENCODING=UTF8",
         "postgres", "psql", "-X", "-U", "postgres", "-d", database,
         "-v", "ON_ERROR_STOP=1", "-At"],
        cwd=ROOT, input=statement, capture_output=True, encoding="utf-8",
    )
    if result.returncode:
        raise RuntimeError(result.stderr.strip())
    return result.stdout.strip()


def literal(value):
    return "'" + str(value).replace("'", "''") + "'"


def main():
    names = ",".join(f"({i},{literal(name)})" for i, name in enumerate(REVIEWER_NAMES, 1))
    allowed_names = ",".join(literal(name) for name in REVIEWER_NAMES)
    # Same known demo password hash as the repository's original customer seed.
    sql("cinema_auth_db", f"""
    BEGIN;
    INSERT INTO users(email,password_hash,full_name,enabled,email_verified)
    SELECT 'review.customer' || lpad(n::text,2,'0') || '@example.com',
      '$2y$10$EF16s.OkiRXS3Zt4PQaxbOirxjqeXgY3GeOWHwwX9WUKjMt/TKEf6',
      full_name, true, true
    FROM (VALUES {names}) AS seed(n,full_name) ON CONFLICT(email) DO NOTHING;
    UPDATE users u SET full_name=seed.full_name
    FROM (VALUES {names}) AS seed(n,full_name)
    WHERE u.email='review.customer' || lpad(seed.n::text,2,'0') || '@example.com'
      AND u.full_name='Demo Reviewer ' || lpad(seed.n::text,2,'0');
    INSERT INTO users_roles(user_id,role_id)
    SELECT u.user_id,r.role_id FROM users u CROSS JOIN roles r
    WHERE u.email ~ '^review[.]customer(0[1-9]|10)@example[.]com$'
      AND u.full_name IN ({allowed_names}) AND r.name='ROLE_CUSTOMER'
    ON CONFLICT DO NOTHING;
    COMMIT;
    """)
    customers = json.loads(sql("cinema_auth_db", f"""
      SELECT json_agg(u) FROM (SELECT user_id,email,full_name FROM users
      WHERE email ~ '^review[.]customer(0[1-9]|10)@example[.]com$'
      AND full_name IN ({allowed_names}) AND enabled AND email_verified) u
    """))
    assert customers and len(customers) == 10, "Expected 10 verified demo customers"
    movies = json.loads(sql("cinema_movie_db", """
      SELECT json_agg(m) FROM (SELECT id,title,duration_minutes FROM movies) m
    """))
    assert movies, "No movies available"
    movie_ids = ",".join(str(int(m["id"])) for m in movies)
    # Closed screenings in 2000 avoid occupying current rooms or seats.
    sql("cinema_showtime_db", "BEGIN;" + "\n".join(
        f"""INSERT INTO showtimes(movie_id,room_id,start_time,end_time,price,status)
        SELECT {int(m['id'])},(SELECT min(id) FROM rooms),
          timestamp '2000-01-01' + {int(m['id'])} * interval '1 day',
          timestamp '2000-01-01' + {int(m['id'])} * interval '1 day'
            + {int(m['duration_minutes'])} * interval '1 minute',0,'CLOSED'
        WHERE NOT EXISTS(SELECT 1 FROM showtimes WHERE movie_id={int(m['id'])}
          AND start_time=timestamp '2000-01-01' + {int(m['id'])} * interval '1 day');"""
        for m in movies
    ) + "COMMIT;")
    shows = json.loads(sql("cinema_showtime_db", f"""
      SELECT json_agg(s) FROM (SELECT movie_id,min(id) AS id FROM showtimes
      WHERE movie_id IN ({movie_ids}) AND start_time=timestamp '2000-01-01'
        + movie_id * interval '1 day' GROUP BY movie_id) s
    """))
    show_ids = {s["movie_id"]: s["id"] for s in shows}
    statements = []
    for index, customer in enumerate(sorted(customers, key=lambda c: c['email'])):
        for movie in movies:
            user_id, movie_id = int(customer["user_id"]), int(movie["id"])
            code = literal(f"DEMO-REVIEW-{user_id}-{movie_id}")
            comments = "ARRAY[" + ",".join(literal(review_comment(movie['title'], stars, index))
                                          for stars in range(1, 6)) + "]"
            statements.append(f"""
              INSERT INTO bookings(booking_code,user_id,customer_email,showtime_id,
                status,total_amount,movie_title,show_time,checked_in_at,created_at)
              VALUES({code},{user_id},{literal(customer['email'])},{show_ids[movie_id]},
                'CONFIRMED',0,{literal(movie['title'])},
                timestamp '2000-01-01' + {movie_id} * interval '1 day',
                timestamp '2000-01-01' + {movie_id} * interval '1 day',
                timestamp '2000-01-01' + {movie_id} * interval '1 day')
              ON CONFLICT(booking_code) DO NOTHING;
              WITH sample AS MATERIALIZED (SELECT COALESCE(
                (SELECT rating FROM movie_reviews WHERE user_id={user_id} AND movie_id={movie_id}),
                (1+floor(random()*5))::smallint) AS stars)
              INSERT INTO movie_reviews(movie_id,user_id,booking_id,reviewer_name,rating,comment)
              SELECT {movie_id},{user_id},b.id,{literal(customer['full_name'])},s.stars,
                ({comments})[s.stars]
              FROM bookings b CROSS JOIN sample s WHERE b.booking_code={code}
              ON CONFLICT(user_id,movie_id) DO UPDATE
                SET reviewer_name=EXCLUDED.reviewer_name, comment=EXCLUDED.comment
              WHERE movie_reviews.comment LIKE '[Demo]%'
                AND movie_reviews.booking_id=EXCLUDED.booking_id;
            """)
    sql("cinema_booking_db", "BEGIN;" + "\n".join(statements) + "COMMIT;")
    ids = ",".join(str(int(c["user_id"])) for c in customers)
    result = json.loads(sql("cinema_booking_db", f"""
      SELECT json_build_object('customers',count(DISTINCT r.user_id),
        'movies',count(DISTINCT movie_id),'reviews',count(*),
        'invalid',count(*) FILTER(WHERE rating NOT BETWEEN 1 AND 5
          OR b.checked_in_at IS NULL OR b.user_id<>r.user_id))
      FROM movie_reviews r JOIN bookings b ON b.id=r.booking_id
      WHERE r.user_id IN ({ids}) AND r.movie_id IN ({movie_ids})
    """))
    assert result["reviews"] == 10 * len(movies) and result["invalid"] == 0, result
    print(json.dumps(result))


if __name__ == "__main__":
    main()
