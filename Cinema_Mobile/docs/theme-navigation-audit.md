# Theme and Navigation Audit

Final follow-up (2026-11-02): The narrow booking-card total overflow below is
fixed by placing the code and amount on separate rows. All 13 account web layout
tests pass, including the original 900 px regression. The findings and measurements
below describe the earlier audit state.

What this repo does: Cinema is a Flutter cinema booking app with a separate staff website and ASP.NET services. This audit covers theme changes, the shared backgrounds, liquid glass, and customer and staff navigation. The assumed load is one active browser tab at desktop and phone widths, with a 60 fps animation target.

## Must fix

1. **Large booking totals overflow narrow desktop cards** (`lib/features/booking/screens/my_bookings_screen.dart:417`). Open My Bookings at 900 px with a booking containing 20 seats. Status: reported, not changed.
   - **What this is:** A row places the booking code beside the full ticket price.
   - **Problem:** The price has no width constraint. The row overflows by 26 px in `account_web_layout_test.dart`.
   - **Fix:** Give the total its own full-width row when the card is narrow. Keep the full amount readable.
   - **If we skip it:** Long totals extend beyond the card. The full Flutter test suite still has this failure.

## Should fix

2. **Theme changes repeat expensive painting** (`lib/core/widgets/cinema_background.dart:41`, `lib/features/home/screens/home_screen.dart:927`). Status: changed and tested.
   - **What this is:** The background paints film paths, glows, and text motifs; the featured poster uses blur and masks.
   - **Problem:** Changing the animated palette previously invalidated the background painter every frame. The poster also shared its parent's repaint work.
   - **Fix:** Paint fixed dark and light backgrounds into separate repaint boundaries and fade between them. Isolate the poster's painting and reuse the two ThemeData values.
   - **If we skip it:** Each theme change repeats work unrelated to the changing controls. Debug performance is especially poor.

3. **Some elements jump halfway through the theme animation** (`lib/features/booking/widgets/booking_detail_content.dart:14`, `lib/features/home/screens/home_screen.dart:1093`). Status: changed and tested.
   - **What this is:** Theme brightness and `isLight` are binary values, while palette lightness changes continuously.
   - **Problem:** Booking details selected all their colors from binary brightness. Featured text changed from 38 to 34 px and logo letter spacing changed during the transition. Panels also switched decoration types and radii abruptly.
   - **Fix:** Interpolate booking colors and panel styling from palette lightness. Keep headline size and logo spacing stable.
   - **If we skip it:** Text can reflow, and colors or surfaces snap even when frame rendering is fast.

4. **Light mode hides much of the liquid effect** (`lib/core/widgets/cinema_account_widgets.dart:372`). Status: changed; existing optical pixel tests pass for both themes.
   - **What this is:** One navigation component already handles the glass shape, touch response, and refraction shader.
   - **Problem:** Light mode replaced the transparent glass gradient with a much more opaque surface and changed elevation at the theme threshold.
   - **Fix:** Use the same glass gradient, refraction, shape, and elevation in both modes. Interpolate shadow opacity and keep theme-aware text colors.
   - **If we skip it:** The light bar looks like a different material and its shadow changes abruptly.

## Navigation Changes

- Hide page Back controls in the desktop layout, including authentication, booking details, shared page headers, and staff page headers.
- Hide the payment-result Close and Back to home controls in that layout.
- Keep the existing desktop top menu, mobile Back controls, and mobile bottom navigation.
- Keep booking, save, payment, retry, form, pagination, carousel, and dialog-cancel actions.
- Preserve the existing 900 px breakpoint. Narrow web windows continue to use the mobile layout; this change does not distinguish a native phone from a phone-sized browser window.

## Measurement and Checks

- Edge headless, Home, widths 1440 and 390, six theme changes each; the first two changes are excluded from frame summaries.
- Initial debug p95 frame intervals: about 250 ms desktop and 225 ms phone layout. After the initial changes, debug remained slow: about 275 ms and 200 ms. These measurements do not establish a debug speed improvement.
- Final release p95 frame intervals: about 75 ms desktop and 50 ms phone layout. These are browser animation-frame intervals, not Flutter CPU/GPU frame timings or a controlled hardware benchmark.
- Release performs better than debug in these runs, but still misses the 16.7 ms target. The difference cannot be attributed solely to the code changes: the build mode also differs. No conclusion that the user's machine is faulty is supported.
- Browser GPU compositing was enabled. Edge reported Intel Iris Xe and NVIDIA RTX 3050 laptop adapters; this does not establish which adapter performed each draw.
- `flutter analyze`: passed. Customer release web build: passed.
- Final focused suite: 99 tests passed, including navigation, theme interpolation, cached background layers, reduced motion, optical glass pixels, booking holds, and payment flows.
- A full suite run found the separate 900 px total overflow and a new test expectation that was subsequently corrected. The corrected focused tests pass; the overflow still reproduces independently. The full suite is not reported as green.
- Playwright verified Back is absent at 1440 px and present at 390 px on movie detail and login. Home screenshots were inspected in both modes and widths, with no captured Flutter exceptions.

Verdict: The code had avoidable repaint work and visible theme discontinuities, and debug mode adds substantial overhead. The requested navigation and shared glass changes are implemented. Use the release preview to assess the result; smooth 60 fps is not established by these measurements.

Not checked: backend internals, load across multiple users, real phone hardware, a before/after release benchmark of the original code, and a full CPU/GPU trace. The separate booking-total overflow is reported rather than changed.
