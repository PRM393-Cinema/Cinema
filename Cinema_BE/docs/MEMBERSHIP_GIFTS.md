# Membership gifts

- VIP: one VIP-seat ticket and one combo of choice per six-month cycle.
- VVIP: two tickets (any seat type) and two combos of choice per cycle.
- The first gift allocation starts when an eligible member first loads their membership card or uses gifts. Renewal is six calendar months later, without carrying over unused gifts. Missed cycles do not accumulate.
- VIP → VVIP adds one ticket and one combo within the current cycle; the renewal date stays the same.
- Select seats and combos, then enable **Use membership gifts** in Booking Summary. The most expensive eligible selected items are covered first, up to the remaining quota. Each seat counts as one ticket.
- Gifts replace promotions and points. Any remaining amount follows normal payment; a zero-total booking is confirmed directly.
- Pending orders reserve gifts atomically. Cancelling or expiring an order restores them only within the original cycle. A late payment for an expired gift order follows the existing refund flow.
- The current concessions catalog identifies combos by the `Combo` name prefix. Standalone snacks and drinks are excluded.

Apply `docker/postgres/migrations/2026-10-29_cinema_member_gifts.sql` via the compose migration service before running the updated BookingService. MovieService must also be rebuilt to return seat types for server-side VIP validation.
