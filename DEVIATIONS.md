# Deviations

## CI `dart format` scope

`ci.yml` runs `dart format --output=none --set-exit-if-changed packages apps tool` instead of `.` because the workflow unpacks the pinned Flutter SDK under `$HOME/flutter`, and formatting `.` would include that SDK tree and fail spuriously. All project Dart sources under `packages/`, `apps/`, and `tool/` are still checked.
