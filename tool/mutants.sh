#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

export PATH="/opt/flutter/bin:${PATH:-}"

BACKUP_DIR="$(mktemp -d)"
trap 'rm -rf "$BACKUP_DIR"' EXIT

apply_mutant() {
  local id="$1"
  local file="$2"
  local pattern="$3"
  local replacement="$4"
  if ! grep -qE "$pattern" "$file"; then
    echo "mutant $id: pattern did not match in $file" >&2
    exit 1
  fi
  sed -i -E "s|$pattern|$replacement|" "$file"
}

backup_file() {
  local file="$1"
  cp "$file" "$BACKUP_DIR/$(echo "$file" | tr '/' '_')"
}

restore() {
  for file in "$@"; do
    cp "$BACKUP_DIR/$(echo "$file" | tr '/' '_')" "$file"
  done
}

run_test_expect_fail() {
  if dart test "$@" >/dev/null 2>&1; then
    echo "mutant survived: dart test $*" >&2
    exit 1
  fi
}

echo "M1: estop blocked on stale seq"
backup_file packages/robot_protocol/lib/src/session_gate.dart
apply_mutant M1 packages/robot_protocol/lib/src/session_gate.dart \
  'if \(sessioned\.type == CommandType\.estop\) \{' \
  'if (false \&\& sessioned.type == CommandType.estop) {'
run_test_expect_fail packages/robot_protocol
restore packages/robot_protocol/lib/src/session_gate.dart

echo "M2: estop braking uses aMax"
backup_file packages/robot_sim/lib/src/plant.dart
apply_mutant M2 packages/robot_sim/lib/src/plant.dart \
  'aLin = config\.aEstop;' \
  'aLin = config.aMax;'
run_test_expect_fail packages/robot_sim/test/estop_test.dart
restore packages/robot_sim/lib/src/plant.dart

echo "M3: deadman check removed"
backup_file packages/robot_sim/lib/src/plant.dart
apply_mutant M3 packages/robot_sim/lib/src/plant.dart \
  'if \(config\.deadmanEnabled &&' \
  'if (false \&\& config.deadmanEnabled \&\&'
run_test_expect_fail packages/robot_sim/test/deadman_test.dart
restore packages/robot_sim/lib/src/plant.dart

echo "M4: protective stop removed"
backup_file packages/robot_sim/lib/src/plant.dart
apply_mutant M4 packages/robot_sim/lib/src/plant.dart \
  'if \(config\.protectiveStopEnabled &&' \
  'if (false \&\& config.protectiveStopEnabled \&\&'
run_test_expect_fail packages/robot_sim/test/protective_stop_test.dart
restore packages/robot_sim/lib/src/plant.dart

echo "M5: duplicate seq re-applies command"
backup_file packages/robot_protocol/lib/src/session_gate.dart
apply_mutant M5 packages/robot_protocol/lib/src/session_gate.dart \
  'return cached;' \
  'return null;'
run_test_expect_fail packages/robot_protocol
restore packages/robot_protocol/lib/src/session_gate.dart

echo "M6: estop_reset ignores moving check"
backup_file packages/robot_sim/lib/src/sim.dart
if ! grep -q 'estop_reset_moving_guard' packages/robot_sim/lib/src/sim.dart; then
  echo "mutant M6: anchor missing in packages/robot_sim/lib/src/sim.dart" >&2
  exit 1
fi
sed -i '/estop_reset_moving_guard/{n;s/if (!plant.fullyStopped())/if (false \&\& !plant.fullyStopped())/}' \
  packages/robot_sim/lib/src/sim.dart
run_test_expect_fail packages/robot_sim/test/estop_test.dart
restore packages/robot_sim/lib/src/sim.dart

echo "full suite (unmodified tree)"
dart test packages/robot_protocol
dart test packages/robot_sim
dart test packages/robot_server

echo "all mutants killed"
