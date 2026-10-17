# Flutter design system

Sprint 4.4 centralizes visual policy without moving business behavior into
widgets. `AppDesignPreset` composes Flutter `ThemeData`; `AppDesignTokens` and
`AppMotionTokens` are theme extensions consumed by presentation code. The
production `command-center` preset is injectable through
`appDesignPresetProvider`, and tests prove that an alternate preset restyles
migrated components without feature changes.

## Tokens and typography

- Semantic colors cover canvas/surfaces/borders, text, success/warning/danger/
  information, selection/disabled states, vehicle connectivity/motion,
  maintenance, trip phases, and map route/trail overlays.
- Spacing, radius, elevation, control-height, 48 px touch targets, responsive
  breakpoints, and maximum content width live in `AppDesignTokens`.
- Noto Sans and Noto Sans Arabic regular/bold files are bundled under
  `assets/fonts`; runtime typography never depends on a CDN. `NOTICE.txt`
  records their packaged license provenance.
- Compact is below 600 px, medium is 600–1023 px, and expanded begins at
  1024 px. Feature code asks `AppBreakpoints` rather than introducing new raw
  width thresholds.

## Components and ownership

`AppPageHeader`, `AppMetricCard`, `AppStatusBadge`, and `AppStatePanel` accept
typed display values/callbacks only. They perform no API calls and own no
business state. Feature repositories/controllers retain polling, authorization,
mutations, and latest-wins behavior. The map widget retains renderer, camera,
annotation, and selection ownership; responsive panels are overlays and do not
recreate it during polling.

## Motion and accessibility

Fast, standard, and emphasized transitions are 150/220/300 ms with centralized
curves. `MediaQuery.disableAnimations` reduces nonessential motion to zero
without suppressing state changes. Status always has a label/icon in addition
to color. Controls use directional layout, localized semantics/tooltips, visible
focus supplied by Material 3, and at least 48 px touch targets.

## Adding a future preset

Create a new `AppDesignPreset` with a complete `AppDesignTokens` instance and
override `appDesignPresetProvider` at the application composition boundary.
Do not branch feature controllers, API contracts, routes, or business models by
brand. Add component-level tests at 360, 768, and 1440 px and in English/Arabic;
new breakpoint or motion values belong in the token layer.
