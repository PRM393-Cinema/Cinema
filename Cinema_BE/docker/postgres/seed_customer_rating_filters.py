"""Local demo ratings for khachhang1@gmail.com, covering every star filter.

Run after seed_demo_reviews.py with the local Docker Compose stack running.
Existing reviews, account credentials and real bookings are left intact.
"""
import json
import random

from seed_demo_reviews import literal, sql

EMAIL = "khachhang1@gmail.com"


def main():
    customers = json.loads(sql("cinema_auth_db", f"""
      SELECT json_agg(u) FROM (SELECT user_id,email,full_name FROM users
      WHERE email={literal(EMAIL)} AND enabled AND email_verified
        AND EXISTS(SELECT 1 FROM users_roles ur JOIN roles r ON r.role_id=ur.role_id
          WHERE ur.user_id=users.user_id AND r.name='ROLE_CUSTOMER')) u
    """))
    assert customers and len(customers) == 1, "Expected one active verified customer"
    customer = customers[0]
    user_id = int(customer["user_id"])
    movies = json.loads(sql("cinema_movie_db", """
      SELECT json_agg(m ORDER BY id) FROM (SELECT id,title FROM movies) m
    """))
    assert movies and len(movies) >= 5, "Need at least five movies for all star filters"
    shows = json.loads(sql("cinema_showtime_db", """
      SELECT json_agg(s) FROM (SELECT movie_id,min(id) AS id FROM showtimes
      WHERE start_time=timestamp '2000-01-01' + movie_id * interval '1 day'
        AND status='CLOSED' GROUP BY movie_id) s
    """)) or []
    show_ids = {int(s["movie_id"]): int(s["id"]) for s in shows}
    assert all(int(m["id"]) in show_ids for m in movies), "Run seed_demo_reviews.py first"
    ratings = [1 + i % 5 for i in range(len(movies))]
    random.shuffle(ratings)
    comments = [
        "[Demo] Not my taste; the pacing needs work.",
        "[Demo] A few good moments, but the story felt uneven.",
        "[Demo] Enjoyable overall, with some room for improvement.",
        "[Demo] Great performances and visuals. Worth watching.",
        "[Demo] Loved the story and atmosphere. Highly recommended.",
    ]
    statements = []
    for movie, rating in zip(movies, ratings):
        movie_id = int(movie["id"])
        code = literal(f"DEMO-REVIEW-{user_id}-{movie_id}")
        statements.append(f"""
          INSERT INTO bookings(booking_code,user_id,customer_email,showtime_id,
            status,total_amount,movie_title,show_time,checked_in_at,created_at)
          VALUES({code},{user_id},{literal(EMAIL)},{show_ids[movie_id]},'CONFIRMED',0,
            {literal(movie['title'])},timestamp '2000-01-01' + {movie_id} * interval '1 day',
            timestamp '2000-01-01' + {movie_id} * interval '1 day',
            timestamp '2000-01-01' + {movie_id} * interval '1 day')
          ON CONFLICT(booking_code) DO NOTHING;
          INSERT INTO movie_reviews(movie_id,user_id,booking_id,reviewer_name,rating,comment)
          SELECT {movie_id},{user_id},b.id,{literal(customer['full_name'])},
            {rating},{literal(comments[rating-1])} FROM bookings b
          WHERE b.booking_code={code} AND b.user_id={user_id} AND b.checked_in_at IS NOT NULL
          ON CONFLICT(user_id,movie_id) DO NOTHING;
        """)
    movie_ids = ",".join(str(int(m["id"])) for m in movies)
    # Closed demo screenings do not occupy any current seats or create payments.
    sql("cinema_booking_db", "BEGIN;" + "\n".join(statements) + "COMMIT;")
    result = json.loads(sql("cinema_booking_db", f"""
      SELECT json_build_object('email',{literal(EMAIL)},'reviews',count(*),
        'stars',array_agg(DISTINCT r.rating ORDER BY r.rating),
        'invalid',count(*) FILTER(WHERE b.user_id<>r.user_id OR b.checked_in_at IS NULL))
      FROM movie_reviews r JOIN bookings b ON b.id=r.booking_id
      WHERE r.user_id={user_id} AND r.movie_id IN ({movie_ids});
    """))
    assert result["reviews"] == len(movies) and result["invalid"] == 0, result
    assert result["stars"] == [1, 2, 3, 4, 5], result
    print(json.dumps(result))


if __name__ == "__main__":
    main()
