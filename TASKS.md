# Tasks: flutter-robot-operator

Build in this order. Each task ends with its acceptance check passing locally and in CI. Criterion numbers refer to `PLAN.md` section 11. Never weaken a test or threshold to get green; fix the code, or record a measured reason in `DEVIATIONS.md`.

## T1. Workspace and CI skeleton

- Root `pubspec.yaml` as a pub workspace with the three packages and the app; `analysis_options.yaml` using `lints` / `flutter_lints`.
- `ci.yml` with the five jobs from PLAN section 12, installing Flutter 3.47.9 from the pinned archive with a sha256 check, all actions pinned by SHA.
- Accept: `dart pub get` at the root resolves; the `dart` job runs format and analyze green on an empty test suite that contains one real test per package.

## T2. robot_protocol

- Messages, strict codec (exact keys, int vs double, finite numbers, UTF-8 byte limit, binary rejection), error codes, `SessionGate` with the sequence and e-stop rules in PLAN section 7 and a 64-entry response cache.
- Fixture files for accept and reject cases (at least 20 rejects).
- Accept: criteria 10 and 11 (codec part), with a counting fake applier.

## T3. robot_sim

- `SimConfig.standard`, `GridMap` (exact clearance, inflated occupancy), plant with the tick order in PLAN section 5, controller, mission state machine, latch, deadman, predictive protective stop, mission validation.
- A test-only constructor that skips validation (for criterion 8) and config overrides for the negative tests.
- `tool/regen_golden.dart` and `test/golden/demo_mission_trace.txt`.
- Accept: criteria 1 to 9 and the VM half of 13, plus the negative configuration tests (braking at `aMax`, instant snap, no deadman, no protective stop) each detected.

## T4. robot_server

- `dart:io` `HttpServer` and `WebSocketTransformer`, one operator socket, injectable `TickSource` (timer or manual), snapshot every tick, frame-rate limit, disconnect handling.
- Accept: criterion 12 over a real localhost socket with a manual tick source and 5 s timeouts on every await.

## T5. dart2js parity

- `tool/parity_js.dart` (prints the demo-mission trace), compiled with `dart compile js -O2` and run with Node; `tool/parity_compare.dart` compares it with the VM run.
- Accept: criterion 13 in the `dart` job.

## T6. Operator app

- Transport interface, `LocalSimTransport` (real codec and `SessionGate`), `WsTransport` behind a conditional import, `OperatorController` (`ChangeNotifier`), map painter, mission bar, e-stop, status panel, link-loss switch, event log, title mirroring, semantics on.
- Accept: criterion 14 with `flutter test`; `flutter build web --release --no-web-resources-cdn --base-href /flutter-robot-operator/` succeeds.

## T7. Browser end-to-end and screenshot

- `apps/operator_app/e2e` with a lockfile pinning `@playwright/test` 1.65.0 and `http-server` 14.1.1, serving the built site under `/flutter-robot-operator/`.
- Accept: criterion 15; `docs/demo.png` at 1280x720 shows the robot mid-mission with the simulation-only banner; commit the image produced by the test.

## T8. Mutation check

- `tool/mutants.sh` with mutants M1 to M6 from PLAN section 10; checked `sed` (fail if no match), restore with `git checkout --`, final full suite.
- Accept: criterion 16 in the `mutants` job.

## T9. Android

- `flutter build apk --debug` in the `android` job.
- Accept: criterion 17.

## T10. NOTICE, README, docs

- `NOTICE` with every dependency and tool, version and license; `tool/notice_check.dart` (criterion 19).
- `README.md`: simulation-only notice at the top, what it shows, how it differs from velocity teleop, how to run the server and app, the safety semantics with the measured tick numbers, browser suspension caveat, "How this was verified" table, idea credits from `REFERENCES.md`.
- `docs/verification.md`: every criterion mapped to a test name and CI job.
- SPDX headers (`// SPDX-License-Identifier: Apache-2.0`) in source files.
- Accept: criteria 18, 19 and 21.

## T11. Pages

- `pages.yml` as in PLAN section 12, with a post-deploy smoke check of status 200 and the title.
- Accept: criterion 20 once merged to `main`.
