\connect cinema_booking_db
CREATE TABLE IF NOT EXISTS member_gifts (
 user_id bigint PRIMARY KEY REFERENCES loyalty_accounts(user_id),
 tier text NOT NULL, renews_at timestamp NOT NULL,
 tickets integer NOT NULL CHECK(tickets>=0), combos integer NOT NULL CHECK(combos>=0)
);
CREATE TABLE IF NOT EXISTS member_gift_uses (
 booking_id bigint PRIMARY KEY REFERENCES bookings(id),
 user_id bigint NOT NULL REFERENCES loyalty_accounts(user_id),
 renews_at timestamp NOT NULL, tickets integer NOT NULL, combos integer NOT NULL,
 discount numeric(12,2) NOT NULL
);
