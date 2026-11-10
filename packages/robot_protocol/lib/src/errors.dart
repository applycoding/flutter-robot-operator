// SPDX-License-Identifier: Apache-2.0

/// Protocol and simulation reject / error codes (version 1).
abstract final class ProtocolCodes {
  static const invalid = 'invalid';
  static const binaryNotSupported = 'binary_not_supported';
  static const frameTooLarge = 'frame_too_large';

  static const wrongSession = 'wrong_session';
  static const seqReused = 'seq_reused';
  static const staleSeq = 'stale_seq';
  static const seqGap = 'seq_gap';

  static const stillMoving = 'still_moving';
  static const estopLatched = 'estop_latched';
  static const deadman = 'deadman';

  static const invalidMission = 'invalid_mission';
  static const waypointInObstacle = 'waypoint_in_obstacle';
  static const segmentBlocked = 'segment_blocked';
  static const outOfMap = 'out_of_map';
  static const obstacleAhead = 'obstacle_ahead';
}
