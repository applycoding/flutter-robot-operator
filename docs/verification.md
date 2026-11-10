# Verification map (PLAN.md section 11)

**Simulation only.** This table maps each success criterion to the asserting test name(s) and CI job(s).

| # | Criterion summary | Test name(s) | CI job |
| --- | --- | --- | --- |
| 1 | Straight-line oracle ticks 1–20 | `straight-line oracle x_k and v_15` (`plant_test.dart`) | `dart` |
| 2 | Speed/accel limits every demo tick | `limits on every demo mission tick` (`plant_test.dart`) | `dart` |
| 3 | Demo mission fixed ticks 300/600/700 | `fixed ticks and clearance` (`mission_test.dart`) | `dart` |
| 4 | Golden trace 1–700 | `lines 1-700 match golden file` (`mission_test.dart`) | `dart` |
| 5 | E-stop bounded braking | `bounded decel and rest timing` (`estop_test.dart`) | `dart` |
| 6 | E-stop latch rules | `same-tick reset, resume while latched, reset at E+7` (`estop_test.dart`) | `dart` |
| 7 | Deadman trip and resume | `criterion 7 deadman` (`deadman_test.dart`) | `dart` |
| 8 | Protective stop | `criterion 8 protective stop` (`protective_stop_test.dart`) | `dart` |
| 9 | Mission validation | `criterion 9 validation` (`validation_test.dart`) | `dart` |
| 10 | SessionGate sequence rules | table groups in `session_gate_test.dart` | `dart` |
| 11 | Strict codec + trajectory | fixture groups in `codec_test.dart`; `moving robot trajectory unchanged under malformed frames` | `dart` |
| 12 | WebSocket integration | `criterion 12 server integration` (`ws_integration_test.dart`) | `dart` |
| 13 | Determinism + dart2js parity | `two VM demo traces identical` (`determinism_test.dart`); `tool/parity_compare.dart` | `dart` |
| 14 | Flutter unit/widget tests | `flutter test` (`controller_test`, `widgets_test`, `world_to_screen_test`, `local_transport_test`) | `flutter` |
| 15 | Playwright release web | `demo.spec.ts` | `e2e` |
| 16 | Mutation M1–M6 | `tool/mutants.sh` | `mutants` |
| 17 | Android debug APK | `flutter build apk --debug` | `android` |
| 18 | Format + analyze | `dart format --set-exit-if-changed`; `flutter analyze --fatal-infos` | `dart`, `flutter` |
| 19 | NOTICE completeness | `tool/notice_check.dart` | `dart` |
| 20 | CI gates + Pages deploy | all jobs in `ci.yml`; `pages.yml` smoke | all jobs / `pages` on `main` |
| 21 | Simulation-only honesty | README, `web/index.html`, in-app banner, `docs/demo.png` | review + `e2e` |
