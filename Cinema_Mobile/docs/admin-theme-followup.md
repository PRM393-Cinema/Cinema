# Admin entry and theme transition audit

Final follow-up (2026-11-02): The preferred local preview now serves both release
builds on port 5174, with the admin entry at `/admin/`; see the README. Paired
Flutter development ports remain an explicitly labelled optional configuration.
The booking-total overflow mentioned below is fixed and its 13-test account layout
suite passes. The audit measurements below remain historical observations.

What this repo does: Cinema has a customer Flutter app and a separate staff/admin Flutter web entry point. Both use the local API gateway. This follow-up audits admin entry and theme switching for one active browser tab at desktop and phone widths, with a 60 fps target.

## Must fix

1. **The local admin link opens the customer app again** (`lib/core/network/api_config.dart:20`, `.vscode/launch.json`). Status: launch configuration and instructions corrected.
   - **What this is:** The customer app links staff to a second website. Without `ADMIN_URL`, it uses `/admin/` on its own origin.
   - **Problem:** The reported customer server on port 5174 runs `lib/main.dart`, while the admin server on 5175 runs `lib/main_admin.dart`. Neither command sets the other site's URL. Requesting `http://localhost:5174/admin/` returns the customer app's HTML and returns the signed-in admin to the same management-account screen.
   - **Fix:** Run the existing two entry points with paired ports and `ADMIN_URL` / `CUSTOMER_URL`. The new **Cinema Web (customer + admin)** VS Code launch does this in release mode. The README and demo instructions now show this setup. The release preview also includes a real admin build at `/admin/`.
   - **If we skip it:** Clicking Open admin website loops back into the customer app. Existing Flutter runs must be relaunched to use the corrected configuration; changing launch.json cannot change their compile-time defines.

## Should fix

2. **Theme interpolation repeatedly rebuilds the interface** (`lib/app/session_app.dart:66`, `lib/app/theme/theme_transition_web.dart`). Status: reduced on supported browsers; steady 60 fps is not established.
   - **What this is:** The old path interpolates the entire Flutter theme for 420 ms. That updates theme-dependent widgets throughout the page on every animation frame.
   - **Problem:** In the release comparison below, browser frame intervals exceed the 16.7 ms budget. The older debug sessions add more work and do not represent release performance.
   - **Fix:** Use the browser's View Transition API, which fades captured page images, while Flutter changes its theme once. A Flutter warm-up frame completes the canvas update while the browser pauses normal frame callbacks. Keep the existing Flutter transition on native targets and browsers without this API. Respect reduced motion and keep the latest selection when toggled repeatedly.
   - **If we skip it:** Theme changes keep repeating expensive work. The new path still has a capture/startup delay: the worst measured desktop interval increased from about 75 to 92 ms. This is a reduction in sustained stalls, not proof that every visible frame reaches 60 fps.

## Release comparison

Edge headless, same customer release build, same machine, one browser, no concurrent builds or test suites. The old path is selected by removing `Document.prototype.startViewTransition` before app startup. Each width gets six toggles; the first two are excluded. Each sample covers a 900 ms window. No page errors were captured.

| Layout | Flutter interpolation p95 | Browser transition p95 | Intervals over 25 ms, old | Intervals over 25 ms, new |
| --- | ---: | ---: | ---: | ---: |
| 1440 × 900 | 66.6 ms | 50.0 ms | 56 / 159 (35.2%) | 24 / 272 (8.8%) |
| 390 × 900 | 50.1 ms | 33.4 ms | 52 / 178 (29.2%) | 31 / 314 (9.9%) |

These are JavaScript animation-frame intervals. They include snapshot preparation and idle time, and do not directly measure compositor frames or Flutter CPU/GPU timings. The result supports a code/runtime contribution to the stalls; it does not establish faulty hardware.

## Checks

- 86 focused Flutter tests passed: customer header links, login continuation for all three protected links, themes, admin/staff/customer access, account locks, and ratings.
- Customer and admin release web builds passed.
- Analysis of the six changed Dart source/test files passed. `git diff --check` passed.
- Edge checks passed at desktop and phone widths, including captured transition frames, repeated toggles, reduced motion, and the browser fallback. No page errors were captured.
- Real local backend check passed: sign in as the seeded admin on the customer site, click Open admin website, reach the admin dashboard, refresh and restore the session, then open Accounts. This check only reads account data.
- The paired VS Code launch configuration was checked for matching ports, URL defines and existing entry points.
- Guest navigation now shows Movies, My tickets, Ratings and Notifications. Protected pages still go through the existing login guard and continue after sign-in.

Verdict: The admin issue is a local server/link mismatch. The corrected launch setup and complete release preview resolve that path. Browser theme switching repeats less work, but a universal 60 fps claim would exceed the evidence.

Not checked: production hosting, real phone hardware, every browser/GPU combination, multi-user backend load, and a full CPU/GPU trace. The old debug servers on 5174/5175 were not restarted. The separate booking-total overflow reported in `theme-navigation-audit.md` remains outside this follow-up.
