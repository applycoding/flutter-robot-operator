# operator_app

**Simulation only. Not connected to a robot. Not a certified safety system.**

Flutter operator UI for the in-repo Dart simulation and WebSocket server. On web it runs the local sim by default; on desktop/Android use `--dart-define=ROBOT_WS=ws://host:8765` to attach to `robot_server`.

```bash
cd apps/operator_app
flutter run -d chrome
flutter build web --release --no-web-resources-cdn --base-href /flutter-robot-operator/
```

See the repository [README](../../README.md) and [docs/verification.md](../../docs/verification.md).
