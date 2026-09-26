# Real-browser acceptance

## Environment

- Release Flutter Web served at `http://localhost:3100`.
- Disposable Compose project `tms-s42`, API at `http://localhost:5180`.
- Dedicated volumes `tms-s42_sprint411_postgres_data` and
  `tms-s42_sprint411_photo_data`; neither retained `tms-smoke` volume was
  referenced or mounted.
- Firefox 145 with geckodriver 0.37.1.
- Separate Firefox WebDriver instances/profiles for Owner and Driver.
- Deterministic routing and browser-independent simulator worker.

## Result

Incomplete. Owner login and global identity passed. The no-default truck
scenario rendered the required explanation and left Driver selection empty.
The default-Driver scenario reached the real assignment screen, but automated
activation of Flutter Web's canvas-backed Truck dropdown did not complete
reliably. The harness recorded `defaultDriverUi: false` and used an explicitly
recorded API assignment fallback only to continue diagnosing the Driver path.
Driver login, identity, and the live workspace then loaded, but the run was
stopped before the complete pickup-to-delivery lifecycle.

Accordingly, none of the required cross-session completion screenshots or
latency values are claimed as passing. Diagnostic screenshots are retained only
to make the failure reproducible. The reusable harness is
`scripts/sprint42-browser-acceptance.py`.

The application itself did not report a backend lifecycle failure during this
run; this boundary is specifically an unfinished browser automation acceptance
and therefore still fails the prompt's Definition of Done.
