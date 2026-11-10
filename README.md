# flutter-robot-operator

**Simulation only. Not connected to a robot. Not a certified safety system.**

A Flutter operator app for one simulated diff-drive robot: waypoint missions with start, pause, resume and stop, a latched e-stop with bounded braking, a heartbeat deadman and a protective stop. Safety rules are enforced on the robot side by a deterministic Dart simulation that runs behind a WebSocket server (desktop/Android) and in-process in the browser.

License: [Apache-2.0](LICENSE). Author: Arpan Bom.

## How this differs from velocity teleop

Unlike [teleop-console-demo](https://github.com/applycoding/teleop-console-demo), this is **not** velocity teleop. There is no velocity-command message. The operator works at **mission** level (waypoints, pause, resume, stop). The same Dart **protocol** and **simulation** run on the VM server and in the browser (parity-tested). Robot-side semantics (e-stop latch, deadman, predictive protective stop) are asserted **tick by tick** in tests.

## Safety semantics (measured ticks)

| Behavior | Measured ticks (prototype) |
| --- | --- |
| Demo mission first `succeeded` | 540 |
| Demo `succeeded` with `v == 0` | 600–700 |
| E-stop from 0.6 m/s | latch immediate; rest by tick **E+6** (≤ 0.10 m travel to E+7) |
| Deadman after last heartbeat at **H** | trip **H+11**, rest **H+22** |
| Protective stop toward wall (validation bypass) | `fault` / `obstacle_ahead`, 0 contact ticks, rest by tick 200 |

E-stop **latches** until `estop_reset` when fully stopped; `mission_resume` does not clear the latch. Deadman pauses a running mission when heartbeat age exceeds 10 ticks (0.5 s at 20 Hz). Protective stop is a simple forward point check (simulation stand-in for a safety scanner, not a certified sensor).

## Browser caveat

GitHub Pages runs the **local** simulation in the browser. If the tab is suspended by the OS, both the UI heartbeat timer and physics may pause; deadman timing is only meaningful while the tab is active.

## Run locally

```bash
dart pub get
dart run packages/robot_server/bin/robot_server.dart --port 8765
```

```bash
cd apps/operator_app
flutter run -d chrome   # local sim (default on web)
flutter run --dart-define=ROBOT_WS=ws://127.0.0.1:8765   # WebSocket to server
```

Release web build (GitHub Pages path):

```bash
flutter build web --release --no-web-resources-cdn --base-href /flutter-robot-operator/
```

## How this was verified

See [docs/verification.md](docs/verification.md) for the full criterion → test → CI mapping. CI runs `dart` tests (sim, protocol, server, parity, NOTICE), `mutants`, `flutter` (analyze + test + web build), Playwright `e2e` (writes [docs/demo.png](docs/demo.png)), and Android debug APK build.

## Idea credits

Protocol envelope ideas: rosbridge. Forward approach check ideas: Nav2 Collision Monitor (documentation only; no Nav2 code). Web dashboard patterns: Open-RMF rmf-web. Details and links: [REFERENCES.md](REFERENCES.md).
