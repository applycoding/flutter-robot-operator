# flutter-robot-operator: plan

Status: decision-complete, ready to build. Simulation only. Author: Arpan Bom. License: Apache-2.0.
Pins verified on 2026-11-10.

A Flutter operator app for one simulated diff-drive robot. The operator loads a waypoint mission, starts, pauses, resumes and stops it, and has a latched emergency stop. The robot-side simulation owns every safety rule: speed and acceleration limits, bounded e-stop braking, a heartbeat deadman, and a predictive protective stop in front of obstacles. The UI only asks. The same pure-Dart simulation runs behind a real WebSocket server (desktop and Android) and in-process in the browser, so the GitHub Pages demo is self-contained.

Every page, README and screenshot says **Simulation only. Not connected to a robot. Not a certified safety system.**

## 1. What makes this different

Existing repos in the same account: `teleop-console-demo` (browser velocity teleop over FastAPI and WebSocket), `humanoid-arm-teleop`, `react-ts-fleet-dashboard`, `robot-fleet-mqtt-telemetry`. This project is not velocity teleop and has no Python. The observable differences, which the README must state:

- Mission-level operation (waypoint missions with pause, resume and stop), not a joystick. No velocity-command message exists in the protocol.
- One shared Dart core: the identical simulation and protocol code runs on the Dart VM server and compiled to JavaScript in the browser, with a parity test between the two.
- Robot-side safety semantics that are tested tick by tick: bounded e-stop braking with a latch, deadman, protective stop, and e-stop priority over sequence rules.
- Flutter for mobile and web from one codebase, with an Android debug build in CI.

## 2. Scope

In:

- `packages/robot_sim`: pure Dart, no dependencies. Plant, limits, map, mission state machine, safety layer.
- `packages/robot_protocol`: pure Dart, no dependencies. Versioned JSON codec, strict validation, session and sequence rules (`SessionGate`).
- `packages/robot_server`: Dart `dart:io` WebSocket server that owns one `RobotSim` and one `SessionGate`.
- `apps/operator_app`: Flutter app. Map painter, live pose and path, mission bar, e-stop, heartbeat and link status, a "simulate operator link loss" switch, event log.
- Tests and CI in sections 10 to 12. GitHub Pages deploy of the web build.

Out of scope: real robots, ROS 2, Nav2, SLAM, sensors, video, joysticks or any velocity teleop, accounts, TLS, auth, multiple operators, multiple robots, iOS, app-store builds, moving obstacles, path planning (the operator places waypoints; the sim validates them), map editing, any claim of functional-safety certification.

## 3. Pinned stack

| Item | Pin | License |
| --- | --- | --- |
| Flutter SDK | 3.47.9 stable, framework commit `c197ca5199e9ee5661e865596c9c07294dfab51c`, Linux archive `stable/linux/flutter_linux_3.47.9-stable.tar.xz`, sha256 `25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a` | BSD-3-Clause |
| Dart SDK | 3.13.7 (bundled with Flutter 3.47.9) | BSD-3-Clause |
| `web_socket_channel` | 3.0.3 (app only, WebSocket client on desktop and Android) | BSD-3-Clause |
| `test` | 1.33.0 (dev, Dart packages) | BSD-3-Clause |
| `async` | 2.13.1 (dev, `StreamQueue` in socket tests) | BSD-3-Clause |
| `lints` | 6.1.0 (dev, Dart packages) | BSD-3-Clause |
| `flutter_lints` | 6.0.0 (dev, app) | BSD-3-Clause |
| `flutter_test` | from the Flutter SDK | BSD-3-Clause |
| Node.js | 24.22.1 LTS ("Krypton") for the browser tests | MIT |
| `@playwright/test` | 1.65.0, with its bundled Chromium | Apache-2.0 (Chromium: BSD-3-Clause and others, not redistributed) |
| `http-server` | 14.1.1 (dev, serves the built site in tests) | MIT |
| CI runner | `ubuntu-24.04` | n/a |

No state-management package: plain `ChangeNotifier` and `ListenableBuilder`. No map plugin: `CustomPainter`. No `integration_test` or `flutter drive` (needs ChromeDriver). The browser end-to-end path is Playwright against the release web build, proven to work in the prototype.

CI installs Flutter by downloading the pinned archive and checking its sha256, not by tracking a channel. All GitHub Actions are pinned by full commit SHA:

| Action | Tag | SHA |
| --- | --- | --- |
| actions/checkout | v7.0.1 | 3d3c42e5aac5ba805825da76410c181273ba90b1 |
| actions/setup-node | v7.1.0 | 949feb2413d6458794dcd2491c4babbbce0c15c1 |
| actions/upload-artifact | v7.0.2 | cf430e030ddbb5b0abf93d22962f4752f3646cd9 |
| actions/download-artifact | v8.0.2 | 9000827ccba6bdab643e8b6fd33ac0654aef8333 |
| actions/cache | v6.1.0 | 55cc8345863c7cc4c66a329aec7e433d2d1c52a9 |
| actions/configure-pages | v6.0.0 | 45bfe0192ca1faeb007ade9deae92b16b8254a0d |
| actions/upload-pages-artifact | v5.0.0 | fc324d3547104276b827a68afc52ff2a11cc49c9 |
| actions/deploy-pages | v5.0.1 | 368f82528645a54fb793d4d04e342629a3f51346 |

## 4. File layout

```
pubspec.yaml                         Dart pub workspace root (resolution: workspace), sdk ^3.13.0
LICENSE  NOTICE  README.md  DEVIATIONS.md
analysis_options.yaml
packages/robot_sim/
  lib/robot_sim.dart                 exports
  lib/src/{config,grid_map,plant,mission,safety,sim}.dart
  test/{plant_test,mission_test,estop_test,deadman_test,protective_stop_test,validation_test,determinism_test}.dart
  test/golden/demo_mission_trace.txt one line per tick, written by tool/regen_golden.dart
packages/robot_protocol/
  lib/robot_protocol.dart
  lib/src/{messages,codec,session_gate,errors}.dart
  test/{codec_test,session_gate_test,fixtures/}.dart
packages/robot_server/
  bin/robot_server.dart              --port (default 8765), --tick-ms (default 50)
  lib/src/server.dart                TickSource injectable: wall-clock timer or manual
  test/ws_integration_test.dart
apps/operator_app/
  lib/main.dart
  lib/src/{transport,local_sim_transport,ws_transport_io,ws_transport_stub,operator_controller,map_painter,mission_bar,estop_button,status_panel,event_log,world_to_screen}.dart
  test/{controller_test,widgets_test,world_to_screen_test,local_transport_test}.dart
  web/                               index.html with the simulation-only title
  e2e/{package.json,package-lock.json,playwright.config.ts,demo.spec.ts}
tool/
  mutants.sh                         applies each source mutant, requires a failing test, restores
  notice_check.dart                  checks NOTICE against the lockfiles
  parity_js.dart  parity_compare.dart  dart2js vs VM trace parity
  regen_golden.dart
docs/demo.png                        written by the Playwright test
docs/verification.md                 criterion -> test -> CI job
.github/workflows/{ci.yml,pages.yml}
```

## 5. Simulation model (`SimConfig.standard`)

Units SI, angles in radians, wrapped to (-pi, pi].

| Constant | Value |
| --- | --- |
| Tick `dt` | 0.05 s (20 Hz). All tests count ticks; no test reads the wall clock. |
| `vMax` | 0.6 m/s (forward only, `v >= 0`) |
| `wMax` | 1.5 rad/s |
| `aMax` (normal accel and decel) | 0.8 m/s^2 |
| `alphaMax` (normal angular accel) | 4.0 rad/s^2 |
| `aEstop` (e-stop and protective-stop braking) | 2.0 m/s^2 |
| `alphaEstop` | 8.0 rad/s^2 |
| `aDeadman` (deadman controlled stop) | 1.0 m/s^2 |
| `heartbeatTimeoutTicks` | 10 (0.5 s) |
| Robot footprint | disc, radius 0.25 m |
| Waypoint tolerance | 0.15 m |
| Map | 10.0 m x 6.0 m, origin at bottom-left, x right, y up, 0.10 m cells; outside the map counts as occupied |
| Obstacles (cell rectangles) | wall x 3.0-3.4, y 0.0-3.5; wall x 6.0-6.4, y 2.5-6.0; pillar x 8.0-8.6, y 1.0-1.6 |
| Start pose | (1.0, 1.0, 0.0), at rest |
| Demo mission | (2.0, 4.6), (4.7, 4.6), (4.7, 1.6), (7.3, 2.3), (9.2, 2.4) |
| Max waypoints | 32 |

Clearance at a pose is the exact Euclidean distance from the robot centre to the nearest occupied cell rectangle or map edge. Contact means clearance < 0.25 m.

Controller (go-to-waypoint), each tick while `running`:

1. If distance to the current waypoint < 0.15 m, advance the index; if it was the last one, mission becomes `succeeded`.
2. `herr = wrap(atan2(dy, dx) - theta)`; `wCmd = clamp(2.5 * herr, ±wMax)`.
3. `vCmd = min(vMax, sqrt(2 * aMax * 0.8 * max(0, dist - 0.05))) * max(0, cos(herr))`, and `vCmd = 0` when `|herr| > 0.8`.

Plant order each tick: (a) deadman check, (b) controller, (c) predictive protective-stop check, (d) choose the active limit (`aEstop` if latched or protective stop, else `aDeadman` if the deadman tripped, else `aMax`), (e) rate-limit `v` toward `vCmd` and `w` toward `wCmd` (when braking for e-stop, protective stop or deadman, `w` decays toward 0 at `alphaEstop`), (f) semi-implicit Euler: `x += v cos(theta) dt; y += v sin(theta) dt; theta += w dt`, using the already-updated `v` and `w`, (g) record clearance and contact. Straight-line oracle from rest with `vCmd = vMax`: `v_k = min(0.6, 0.04 k)`, `x_k = x_0 + dt * sum(v_1..v_k)`, so `x_15 = x_0 + 0.24` m.

Predictive protective stop: while running, check 4 evenly spaced points along the current heading up to `vCmd^2 / (2 aEstop) + vCmd dt + 0.05` m ahead, each with the 0.25 m footprint inflated by the cell half-diagonal. Any hit sets mission `fault` with code `obstacle_ahead` and brakes at `aEstop`. This is a simulation stand-in for a safety scanner, labelled as such.

Mission validation (on `mission_set`): 1 to 32 finite waypoints inside the map, each waypoint and each straight segment (from the current pose through every waypoint) sampled every 0.05 m must be clear of the inflated footprint. Otherwise reject with `invalid_mission` and a reason (`waypoint_in_obstacle`, `segment_blocked`, `out_of_map`).

## 6. State machines

Mission: `idle | ready | running | paused | succeeded | fault`. The e-stop latch, deadman flag and protective-stop flag are separate booleans, never mission states.

| From | Event | Guard | To |
| --- | --- | --- | --- |
| idle, succeeded, fault | `mission_set` valid | not running/paused | ready |
| ready | `mission_start` | not latched, heartbeat fresh | running |
| running | `mission_pause` | | paused (normal decel) |
| running | e-stop latched | | paused (e-stop braking) |
| running | deadman trips | | paused, `deadman = true` (deadman decel) |
| running | protective stop | | fault `obstacle_ahead` (e-stop braking) |
| paused | `mission_resume` | not latched, heartbeat fresh, robot fully stopped | running, same waypoint index; clears `deadman` |
| running, paused, ready | `mission_stop` | | idle (normal decel), waypoints cleared |
| running | last waypoint reached | | succeeded (decel to rest) |

E-stop latch: set by an `estop` command at the moment it is applied (before the next tick). It never resumes anything by itself. `estop_reset` clears it only if at least one tick has passed since the latch and `v == 0` and `w == 0`; otherwise reject `still_moving`. After reset the mission stays `paused` until an explicit `mission_resume`. A latch survives disconnects, reconnects and sessions. `mission_stop` is allowed while latched (it only clears the mission).

Deadman: a heartbeat applied at tick H is fresh through tick H+10. On the first tick after that, a running mission pauses with `deadman = true`. Disconnecting the socket stops heartbeats, so it trips the deadman the same way. In the browser, heartbeats come from a UI timer that is separate from the physics timer, and the "simulate operator link loss" switch stops only the heartbeat timer, so the demo shows the deadman while physics keeps running. Browser tab suspension pauses both timers; the README says so.

## 7. Protocol (version 1)

UTF-8 JSON text frames only. Binary frames: reply `error` `binary_not_supported`, no state change. Max frame 4096 bytes (UTF-8 length). Every message is an object with exactly the listed keys; an unknown or missing key, a wrong type (including `1.0` where an int is required), a non-finite number, or an unknown `type` is `error` `invalid` with no state change.

Client to server: `{"v":1,"type":T,"session":S,"seq":N,"body":{...}}`, except `hello`, which is `{"v":1,"type":"hello"}` and has no session or seq.

| Type | Body |
| --- | --- |
| `hello` | none |
| `heartbeat` | `{}` |
| `estop` | `{}` |
| `estop_reset` | `{}` |
| `mission_set` | `{"waypoints":[[x,y],...]}` |
| `mission_start` / `mission_pause` / `mission_resume` / `mission_stop` | `{}` |

Server to client: `welcome {session, tick_dt_s, map}`, `ack {seq, ok:true}`, `reject {seq, code}`, `error {code}`, `snapshot {tick, x, y, theta, v, w, mission, wp_index, latched, deadman, fault, heartbeat_age_ticks, clearance}` every tick and once right after `welcome`.

Session and sequence rules (`SessionGate`, shared by server and local transport):

- `hello` gets a new random session id; the first command of a session has `seq: 1`. A new session replaces the old one; frames carrying an old session id get `reject` `wrong_session` and change nothing.
- `seq == last + 1`: processed; `last` advances whether the command is accepted or rejected by the sim (the response is cached).
- `seq == last` with a byte-identical frame: the cached response is sent again, the command is not re-applied.
- `seq == last` with different content: `reject` `seq_reused`.
- `seq < last`: `reject` `stale_seq`. `seq > last + 1`: `reject` `seq_gap`; `last` unchanged.
- The cache holds the last 64 responses per session.
- E-stop exception: an `estop` frame that parses and carries the current session is applied whatever its `seq` (stale, gap, duplicate). It is idempotent and does not move `last`. An `estop` before `hello` or with a wrong session is still applied if it arrives on the currently connected socket, and the reply says `ok` with `note: "applied_without_session"`. Safety beats bookkeeping. Every other command needs a valid session.
- One operator socket at a time. A second connection is closed with code 1008. When the socket closes, the session ends (deadman will trip if running); the latch and the plant stay.
- At most 32 frames per tick per socket; overflow closes with 1009.

## 8. Operator app

- Map painter: occupancy, inflated outline, mission polyline, robot disc and heading, travelled path. Pure function `worldToScreen` with unit tests.
- Mission bar: Load demo mission, Start, Pause, Resume, Stop. Buttons are enabled only when the robot-side state would accept them (from the last snapshot); the robot still validates.
- E-stop: large red button, always enabled, sends `estop` on press. Shows LATCHED and a Reset button once the robot reports `v == 0`.
- Status: mission state, latch, deadman, protective stop, heartbeat age, speed, clearance, transport badge `SIM · local` or `SIM · ws`, and the simulation-only notice.
- Event log of acks, rejects and errors.
- Transport interface with `LocalSimTransport` (in-process `RobotSim` plus the real codec and `SessionGate`, so the browser goes through the same validation) and `WsTransport` (conditional import so the web build never pulls `dart:io`). Desktop and Android pick WebSocket with `--dart-define=ROBOT_WS=ws://host:8765`; without it, and always on web, they use the local sim.
- Semantics enabled at start so the browser tests can find controls by role and label. The document title mirrors state: `Robot operator (simulation only) - <mission> - <latched|clear>`.
- Web build: `flutter build web --release --no-web-resources-cdn --base-href /flutter-robot-operator/` so CanvasKit is served from the site and the page makes no external requests.

## 9. Edge cases that must have a test

Stale, duplicate, reused and gap sequence numbers; e-stop with stale seq, wrong session and before hello; `estop_reset` in the same tick as the e-stop; `estop_reset` while moving; `mission_resume` while latched and with a stale heartbeat; `mission_start` while latched; reconnect keeps the latch and the plant, and the first snapshot of the new session shows `latched: true`; old-session frames after reconnect; second client refused; binary frame; 4097-byte frame; extra key; `v: 2`; `seq: 1.0`; NaN and out-of-map waypoints; 33 waypoints; waypoint inside the inflated footprint; segment through a wall; malformed frames while the robot is moving leave the plant trajectory identical to a run without them.

## 10. Test plan

Dart unit tests (`dart test` in each package):

- Plant: straight-line oracle for ticks 1 to 20; speed and accel limits on every tick of the demo mission.
- Mission: demo mission with heartbeats every 2 ticks; per-tick clearance and contact check; state at fixed ticks; trace compared to the checked-in golden file.
- E-stop, deadman, protective stop, validation: tick-indexed assertions in section 11.
- Negative configuration tests (same assertions, weakened configs, using `expect(..., isNot(...))` on the helper's verdict): e-stop braking at `aMax`, e-stop as an instant snap, deadman disabled, predictive stop disabled. Each must be detected.
- Determinism: two runs give identical traces (compare the full `List<String>` of per-tick `x.toString()` etc.).
- Protocol: fixture tables for accept and reject; `SessionGate` table tests with a fake applier that counts calls.

Server integration (`dart test` in `robot_server`, real socket on 127.0.0.1 port 0, manual `TickSource` so assertions are at exact ticks; every await on a frame has a 5 s timeout): hello, mission, motion; e-stop over the socket; reconnect latch persistence; second client refused; binary and oversize frames; old-session frames.

Flutter tests (`flutter test` in the app): controller with a fake transport, widget enable/disable rules, e-stop press sends exactly one `estop`, LocalSimTransport end-to-end for the demo mission through the codec.

dart2js parity: `tool/parity_js.dart` is compiled with `dart compile js -O2` and run in Node; `tool/parity_compare.dart` compares it with the VM run.

Browser end-to-end (Playwright, Chromium, against the release web build served by `http-server` at `/flutter-robot-operator/`): see criterion 15. It writes `docs/demo.png` at 1280x720 with the robot mid-mission.

Mutation check (`tool/mutants.sh`): applies each mutant with a checked `sed` (the script fails if the pattern did not match), runs the relevant tests, requires a non-zero exit, restores with `git checkout -- <file>`, and finally runs the full suite green. Mutants: (M1) e-stop not applied while sequence is stale; (M2) e-stop braking uses `aMax`; (M3) deadman check removed; (M4) protective stop removed; (M5) duplicate seq re-applies the command; (M6) `estop_reset` ignores the moving check.

## 11. Numbered success criteria

All tick numbers are measured on the prototype (section 15) and asserted at fixed ticks, never as a minimum or maximum over a search window. "Every tick" checks are for-all assertions over the whole run.

1. Straight line: from (1.0, 1.0, 0) with one waypoint at (2.6, 1.0), `x_k` matches the closed-form oracle within 1e-12 m for k = 1..20, and `v_15 == 0.6` within 1e-12.
2. Limits: on every tick of the demo mission `0 <= v <= 0.6 + 1e-12`, `|w| <= 1.5 + 1e-12`, `|v_k - v_{k-1}| <= aMax * dt + 1e-12`.
3. Demo mission: state `running` at tick 300; `succeeded` at tick 600 and still `succeeded` with `v == 0` at tick 700; `wp_index == 5`; final position within 0.15 m of (9.2, 2.4); zero contact ticks; clearance >= 0.35 m on every tick (prototype: first success at tick 540, minimum clearance 0.443 m).
4. Golden trace: the demo-mission trace for ticks 1 to 700 equals `test/golden/demo_mission_trace.txt` line for line (values printed with 12 significant digits).
5. E-stop: accelerate to `v = 0.6` on the demo mission, apply `estop` at tick E. Then `latched` is true immediately and mission is `paused`; on every tick from E+1 the speed drop is <= `aEstop * dt + 1e-12` (bounded, not a snap) and > 0 until rest; `v == 0` and `w == 0` at tick E+7 and on every tick through E+107; distance travelled from E to E+7 <= 0.10 m (prototype: rest at E+6, 0.075 m).
6. Latch rules: `estop_reset` at tick E (same tick) returns `still_moving`; `mission_resume` and `mission_start` while latched return `estop_latched`; after a successful `estop_reset` at E+7 the mission stays `paused` and `v == 0` through E+20 until `mission_resume` is sent.
7. Deadman: last heartbeat applied at tick H while at 0.6 m/s. Mission is `running` at H+10, `paused` with `deadman == true` at H+11, speed drop per tick <= `aDeadman * dt + 1e-12`, `v == 0` at H+23 (prototype: H+22). `mission_resume` before a new heartbeat returns `deadman`; after a new heartbeat it returns ok.
8. Protective stop: with validation bypassed through a test-only constructor, a mission straight at the first wall from (1.0, 1.0) ends in `fault` / `obstacle_ahead` with zero contact ticks and `v == 0` by tick 200; the same run with the predictive check disabled has more than 0 contact ticks (prototype: 0 vs 30).
9. Validation: waypoint (3.2, 1.0) is rejected `waypoint_in_obstacle`; a single waypoint (5.0, 1.0) from the start pose is rejected `segment_blocked`; (10.5, 1.0) is `out_of_map`; 33 waypoints and NaN are `invalid`; the demo mission is accepted.
10. Sequence rules: the `SessionGate` table test covers in-order, duplicate (cached reply, applier count unchanged), reused, stale, gap, wrong session and no session, for every command type; e-stop with stale seq, gap seq, wrong session and before hello latches the robot.
11. Strict codec: every reject fixture (at least 20, including extra key, missing key, `v: 2`, `seq: 1.0`, NaN, 4097 bytes, binary) yields `invalid` or the named code, and a robot moving during 50 malformed frames has a trajectory bit-identical to the same run without them.
12. Server over a real socket with a manual tick source: mission start, e-stop applied before the next tick, reconnect where the first snapshot of the new session has `latched: true` and the same tick and pose as before the disconnect, old-session frames rejected `wrong_session`, second client closed with 1008, disconnect while running trips the deadman at the tick from criterion 7.
13. Determinism and parity: two VM runs of the demo mission are identical; the dart2js build run in Node gives the same mission state on every tick, the same first-success tick, and pose differences <= 1e-9 m on every tick (prototype: 4.4e-16 m).
14. Flutter: `flutter analyze` and `flutter test` pass; the e-stop widget test proves one press sends exactly one `estop`; buttons follow the enable rules in section 8; `worldToScreen` round-trips within 0.5 logical px.
15. Browser end-to-end on the release web build: the page title contains `simulation only`; Load demo mission, Start, wait for `running`; E-STOP, then the title shows `latched` and the speed readout reaches 0; Reset, Resume, then `succeeded`; turning on link loss while running shows `deadman`; no request leaves the local server; `docs/demo.png` is written at 1280x720 and uploaded as an artifact.
16. Mutation check: each of M1 to M6 makes at least one test fail; the unmodified tree passes. The CI job fails if any mutant survives or any `sed` pattern did not match.
17. Android: `flutter build apk --debug` succeeds in CI.
18. Lint and format: `dart format --output=none --set-exit-if-changed .` and `flutter analyze --fatal-infos` exit 0.
19. NOTICE: `tool/notice_check.dart` fails unless every package in every `pubspec.lock` and `e2e/package-lock.json` direct dependency, plus Flutter, Dart, Node, Playwright and Chromium, is listed with version and SPDX license, and nothing is listed that is not used. Third-party license texts are included or linked as their licenses require.
20. CI: every job in `ci.yml` runs on every push and pull request and gates; no `continue-on-error`, no `if: false`, no manual-only jobs. The Pages workflow deploys only after `ci.yml` succeeds on the same commit on `main`, and the deployed URL serves the app with status 200 and the simulation-only title.
21. Honesty: README, page title, in-app banner and screenshot say simulation only; no text claims a real robot, production use or safety certification.

## 12. CI

`ci.yml` (push and pull_request), jobs:

1. `dart` - install Flutter (pinned archive, sha256 checked), `dart pub get` at the workspace root, format check, `flutter analyze --fatal-infos`, `dart test` in the three packages, parity (criterion 13), NOTICE check.
2. `mutants` - needs `dart`; runs `tool/mutants.sh`.
3. `flutter` - `flutter test`, `flutter build web --release --no-web-resources-cdn --base-href /flutter-robot-operator/`, upload `build/web` artifact.
4. `e2e` - needs `flutter`; download the artifact, Node 24.22.1, `npm ci` in `apps/operator_app/e2e`, cache and install Playwright Chromium with `--with-deps`, run the Playwright test, upload `demo.png` and the Playwright report.
5. `android` - `flutter build apk --debug` (runner Java 17 and Android SDK).

`pages.yml`: `workflow_run` on `ci` completed; deploys only when the run concluded `success`, the event was `push` and the branch is `main`; downloads that run's `web` artifact by run id; `permissions: pages: write, id-token: write, actions: read`; environment `github-pages`; then a smoke step that fetches the deployed URL and checks the title.

## 13. Risks

- Golden tick drift if a gain or constant changes: constants live only in `SimConfig.standard`; regenerate the golden file with `tool/regen_golden.dart` in the same commit and explain it in the commit message. The fixed-tick criteria (3, 5, 7) have margin over the prototype numbers so a faithful implementation passes without tuning.
- Flutter web in headless Chromium: proven in the prototype with semantics on and the title as the state mirror. If CanvasKit fails to render on the runner, fall back to `--use-angle=swiftshader` args and record it in `DEVIATIONS.md`.
- Android build time and SDK drift on the runner image: if the job cannot pass on the pinned stack, record the red run in `DEVIATIONS.md`; do not delete the job silently.
- dart2js and VM trig may differ in the last bit; criterion 13 allows 1e-9 m on pose but requires identical states.
- Scope creep toward velocity teleop overlaps `teleop-console-demo`; no velocity command is added.

## 14. License and authorship

Apache-2.0. All commits by `Arpan Bom <applycoding@gmail.com>`, no co-author trailers. No code is copied from other projects; `REFERENCES.md` lists ideas and documentation only.

## 15. Prototype record (planning-time evidence)

A throwaway prototype of the sim, codec and a localhost WebSocket server was run on Dart 3.13.7 / Flutter 3.47.9 on Linux, plus a minimal Flutter web page driven by Playwright 1.65.0 headless Chromium.

| Check | Result |
| --- | --- |
| Straight-line oracle | `x_15 = 1.24`, max error 0 over 20 ticks |
| Demo mission | first success tick 540, 0 contact ticks, min clearance 0.443 m, final error 0.062 m, max speed 0.6, max accel 0.8 |
| E-stop from 0.6 m/s | rest at +6 ticks, 0.075 m, max decel 2.0, stays at rest; same-tick reset rejected; resume while latched rejected; reset leaves mission paused |
| E-stop mutant (disabled) | 0.9 m travelled in 30 ticks, never stops |
| Deadman | trips at H+11, rest at H+22; resume with stale heartbeat rejected; disabled mutant never stops |
| Protective stop | fault, 0 contacts, min clearance 0.335 m; disabled mutant 30 contact ticks |
| Determinism | two VM runs identical |
| dart2js in Node vs VM | identical states on 700 ticks, max pose difference 4.4e-16 m |
| WebSocket | e-stop with a stale seq latches; reset while moving rejected; 7 malformed frames rejected with no state change |
| Flutter web headless | title mirrors state, buttons clickable by role through semantics, screenshot written, 0 external requests with `--no-web-resources-cdn` |
