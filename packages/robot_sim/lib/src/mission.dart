// SPDX-License-Identifier: Apache-2.0

/// Mission lifecycle states (e-stop, deadman, protective stop are separate flags).
enum MissionState { idle, ready, running, paused, succeeded, fault }

/// Fault codes when mission is [MissionState.fault].
enum FaultCode {
  obstacleAhead('obstacle_ahead'),
  none('');

  const FaultCode(this.code);
  final String code;
}

/// Reject reasons for validation and command guards.
class RejectCode {
  static const invalidMission = 'invalid_mission';
  static const waypointInObstacle = 'waypoint_in_obstacle';
  static const segmentBlocked = 'segment_blocked';
  static const outOfMap = 'out_of_map';
  static const invalid = 'invalid';
  static const estopLatched = 'estop_latched';
  static const stillMoving = 'still_moving';
  static const deadman = 'deadman';
  static const heartbeatStale = 'heartbeat_stale';
  static const notStopped = 'not_stopped';
  static const badState = 'bad_state';
}
