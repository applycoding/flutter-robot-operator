// SPDX-License-Identifier: Apache-2.0

/// Simulation constants and optional overrides for negative tests.
class SimConfig {
  const SimConfig({
    required this.dt,
    required this.vMax,
    required this.wMax,
    required this.aMax,
    required this.alphaMax,
    required this.aEstop,
    required this.alphaEstop,
    required this.aDeadman,
    required this.heartbeatTimeoutTicks,
    required this.footprintRadius,
    required this.waypointTolerance,
    required this.mapWidth,
    required this.mapHeight,
    required this.cellSize,
    required this.maxWaypoints,
    required this.deadmanEnabled,
    required this.protectiveStopEnabled,
    required this.instantEstopSnap,
    required this.headingGain,
    required this.vCmdDistOffset,
    required this.vCmdHerrLimit,
    required this.protectiveLookaheadExtra,
    required this.protectiveSampleCount,
  });

  static const SimConfig standard = SimConfig(
    dt: 0.05,
    vMax: 0.6,
    wMax: 1.5,
    aMax: 0.8,
    alphaMax: 4.0,
    aEstop: 2.0,
    alphaEstop: 8.0,
    aDeadman: 1.0,
    heartbeatTimeoutTicks: 10,
    footprintRadius: 0.25,
    waypointTolerance: 0.15,
    mapWidth: 10.0,
    mapHeight: 6.0,
    cellSize: 0.10,
    maxWaypoints: 32,
    deadmanEnabled: true,
    protectiveStopEnabled: true,
    instantEstopSnap: false,
    headingGain: 2.5,
    vCmdDistOffset: 0.05,
    vCmdHerrLimit: 0.8,
    protectiveLookaheadExtra: 0.05,
    protectiveSampleCount: 4,
  );

  final double dt;
  final double vMax;
  final double wMax;
  final double aMax;
  final double alphaMax;
  final double aEstop;
  final double alphaEstop;
  final double aDeadman;
  final int heartbeatTimeoutTicks;
  final double footprintRadius;
  final double waypointTolerance;
  final double mapWidth;
  final double mapHeight;
  final double cellSize;
  final int maxWaypoints;
  final bool deadmanEnabled;
  final bool protectiveStopEnabled;
  final bool instantEstopSnap;
  final double headingGain;
  final double vCmdDistOffset;
  final double vCmdHerrLimit;
  final double protectiveLookaheadExtra;
  final int protectiveSampleCount;

  /// Demo mission waypoints per PLAN section 5.
  static const List<List<double>> demoWaypoints = [
    [2.0, 4.6],
    [4.7, 4.6],
    [4.7, 1.6],
    [7.3, 2.3],
    [9.2, 2.4],
  ];

  /// Default start pose (x, y, theta).
  static const List<double> startPose = [1.0, 1.0, 0.0];

  double get cellHalfDiagonal => cellSize * 0.5 * 1.4142135623730951;

  double get inflatedFootprintRadius => footprintRadius + cellHalfDiagonal;

  SimConfig copyWith({
    double? dt,
    double? vMax,
    double? wMax,
    double? aMax,
    double? alphaMax,
    double? aEstop,
    double? alphaEstop,
    double? aDeadman,
    int? heartbeatTimeoutTicks,
    double? footprintRadius,
    double? waypointTolerance,
    double? mapWidth,
    double? mapHeight,
    double? cellSize,
    int? maxWaypoints,
    bool? deadmanEnabled,
    bool? protectiveStopEnabled,
    bool? instantEstopSnap,
    double? headingGain,
    double? vCmdDistOffset,
    double? vCmdHerrLimit,
    double? protectiveLookaheadExtra,
    int? protectiveSampleCount,

    /// Negative-test override: use [aMax] for e-stop / protective braking.
    bool? estopUsesAMax,
  }) {
    final useAMax = estopUsesAMax ?? false;
    return SimConfig(
      dt: dt ?? this.dt,
      vMax: vMax ?? this.vMax,
      wMax: wMax ?? this.wMax,
      aMax: aMax ?? this.aMax,
      alphaMax: alphaMax ?? this.alphaMax,
      aEstop: useAMax ? (aMax ?? this.aMax) : (aEstop ?? this.aEstop),
      alphaEstop: alphaEstop ?? this.alphaEstop,
      aDeadman: aDeadman ?? this.aDeadman,
      heartbeatTimeoutTicks:
          heartbeatTimeoutTicks ?? this.heartbeatTimeoutTicks,
      footprintRadius: footprintRadius ?? this.footprintRadius,
      waypointTolerance: waypointTolerance ?? this.waypointTolerance,
      mapWidth: mapWidth ?? this.mapWidth,
      mapHeight: mapHeight ?? this.mapHeight,
      cellSize: cellSize ?? this.cellSize,
      maxWaypoints: maxWaypoints ?? this.maxWaypoints,
      deadmanEnabled: deadmanEnabled ?? this.deadmanEnabled,
      protectiveStopEnabled:
          protectiveStopEnabled ?? this.protectiveStopEnabled,
      instantEstopSnap: instantEstopSnap ?? this.instantEstopSnap,
      headingGain: headingGain ?? this.headingGain,
      vCmdDistOffset: vCmdDistOffset ?? this.vCmdDistOffset,
      vCmdHerrLimit: vCmdHerrLimit ?? this.vCmdHerrLimit,
      protectiveLookaheadExtra:
          protectiveLookaheadExtra ?? this.protectiveLookaheadExtra,
      protectiveSampleCount:
          protectiveSampleCount ?? this.protectiveSampleCount,
    );
  }
}
