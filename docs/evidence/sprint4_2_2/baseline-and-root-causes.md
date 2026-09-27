# Baseline reproduction and root causes

Baseline was `main` at `5bd5cac`; the worktree was otherwise clean except for
the user-provided Sprint prompt. The previous Sprint 4.2.1 trip-page images were
not treated as basemap evidence.

1. OpenFreeMap Liberty combined `name:latin` and `name:nonlatin` in symbol
   expressions. In Firefox, MapLibre GL JS 6.4.1 reported the RTL plugin as
   `requested`, and the real canvas rendered Arabic in reverse visual order.
2. The Owner input wrapper classified every pointer signal as exploration.
   Wheel zoom therefore paused follow. Poll recentering also used a fixed local
   zoom, discarding the user's zoom.
3. Owner and Driver had separate implicit camera rules, so the same gesture
   produced different follow behavior.
4. Poll updates replaced marker geometry immediately. No latest-wins visual
   interpolator, shortest-angle heading policy, stale stop, or reset snap was
   present.
5. Immutable position history was queried as current state. There was no guarded
   current-position projection, so strict duplicate/equal/older semantics were
   not explicit.
6. Driver workspace resolution stopped after active trip and active vehicle
   session. A unique active default-linked truck was not resolved, and the UI
   returned before building the map.
7. Companies had no tenant-owned operational-area preference, so initial camera
   behavior depended on the first connected truck or generic fallback.

The implementation retained the already-working default-Driver recommendation.
Selenium's Flutter dropdown limitation was kept separate from product behavior.
