# References: flutter-robot-operator

These are references for ideas and documentation only. No source, test, figure or text is copied, translated or vendored from them. Licenses were checked on 2026-11-10 against each project's license file.

Outbound license for this repo: Apache-2.0.

## Not a duplicate of these applycoding repos

| Repo | Difference |
| --- | --- |
| [teleop-console-demo](https://github.com/applycoding/teleop-console-demo) | Browser velocity teleop over FastAPI. This repo has no velocity commands and no Python: mission-level operation in Flutter, with the same Dart simulation on the server and in the browser. |
| [humanoid-arm-teleop](https://github.com/applycoding/humanoid-arm-teleop) | 6-DOF arm teleop with IK. Different robot and problem. |
| [react-ts-fleet-dashboard](https://github.com/applycoding/react-ts-fleet-dashboard) | Read-only fleet monitoring in React. This repo commands one robot and tests robot-side safety. |
| [robot-fleet-mqtt-telemetry](https://github.com/applycoding/robot-fleet-mqtt-telemetry) | MQTT telemetry pipeline into a database. No command path. |

## Idea references

### 1. rosbridge protocol (RobotWebTools/rosbridge_suite)

- URL: https://github.com/RobotWebTools/rosbridge_suite (branch `ros2`, HEAD `beb8018cf7bf`, 2026-11-04), protocol text: https://github.com/RobotWebTools/rosbridge_suite/blob/ros2/ROSBRIDGE_PROTOCOL.md
- License: BSD-3-Clause ("Copyright (c) The Rosbridge Authors").
- Idea: a small JSON envelope with an operation type and ids over a WebSocket. Our envelope, sequence rules and e-stop exception are our own; no ROS is used.

### 2. Nav2 Collision Monitor (ros-navigation/navigation2)

- URL: https://github.com/ros-navigation/navigation2/tree/main/nav2_collision_monitor (HEAD `3b7ec4355be9`, 2026-11-10)
- License: the package declares Apache-2.0 in `package.xml`; the repository LICENSE notes that portions are LGPL-2.1-or-later or Apache-2.0.
- Idea: an "approach" style check that looks ahead along the current motion and stops before contact. Ours is a much simpler point check in a grid map. No Nav2 code is read for implementation or used.

### 3. Open-RMF web dashboard (open-rmf/rmf-web)

- URL: https://github.com/open-rmf/rmf-web (HEAD `ac42d1cec155`, 2026-11-06)
- License: Apache-2.0.
- Idea: operator-facing robot status (mission state, e-stop state, battery-style indicators) shown together with a map. UI and code here are independent.

## Documentation used

- Flutter accessibility and semantics: https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility
- Flutter web renderers and build options: https://docs.flutter.dev/platform-integration/web/renderers and https://docs.flutter.dev/deployment/web
- `CustomPainter`: https://api.flutter.dev/flutter/rendering/CustomPainter-class.html
- Flutter testing overview: https://docs.flutter.dev/testing/overview
- Dart pub workspaces: https://dart.dev/tools/pub/workspaces
- `web_socket_channel`: https://pub.dev/packages/web_socket_channel
- Playwright screenshots: https://playwright.dev/docs/screenshots

## Dependencies (credited in NOTICE)

| Component | Version | License |
| --- | --- | --- |
| Flutter SDK | 3.47.9 | BSD-3-Clause |
| Dart SDK | 3.13.7 | BSD-3-Clause |
| web_socket_channel | 3.0.3 | BSD-3-Clause |
| test | 1.33.0 (dev) | BSD-3-Clause |
| async | 2.13.1 (dev) | BSD-3-Clause |
| lints | 6.1.0 (dev) | BSD-3-Clause |
| flutter_lints | 6.0.0 (dev) | BSD-3-Clause |
| Node.js | 24.22.1 (dev) | MIT |
| @playwright/test | 1.65.0 (dev) | Apache-2.0 |
| http-server | 14.1.1 (dev) | MIT |

Transitive packages from the lockfiles are added to `NOTICE` when the lockfiles are created.
