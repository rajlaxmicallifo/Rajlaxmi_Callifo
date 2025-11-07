import 'package:flutter/material.dart';

import '../features/sim_detection/sim_detection_service.dart';

class SimService {
  final SimDetectionService _simDetectionService = SimDetectionService();

  Future<SimInfoResult> getSimInfo() async {
    try {
      final result = await SimDetectionService.getSimInfo();
      return SimInfoResult(
        simInfo: result,
        availableSims: result['availableSims'] ?? 1,
        simDetectionEnabled: (result['availableSims'] ?? 0) > 0,
        status: '${result['availableSims'] ?? 1} SIM${(result['availableSims'] ?? 1) > 1 ? 's' : ''} detected',
      );
    } catch (e) {
      return SimInfoResult(
        simInfo: {},
        availableSims: 0,
        simDetectionEnabled: false,
        status: 'SIM detection unavailable',
        error: e.toString(),
      );
    }
  }

  Future<String> performSimChange(String newSim, Map<dynamic, dynamic> simInfo) async {
    await Future.delayed(const Duration(seconds: 2));

    if (newSim == 'auto') {
      final sim1State = simInfo['sim1State']?.toString() ?? 'unknown';
      final sim2State = simInfo['sim2State']?.toString() ?? 'unknown';

      if (sim1State == 'ready' && sim2State == 'ready') {
        newSim = 'sim1';
      } else if (sim1State == 'ready') {
        newSim = 'sim1';
      } else if (sim2State == 'ready') {
        newSim = 'sim2';
      } else {
        newSim = 'sim1';
      }
    }

    return newSim;
  }
}

class SimInfoResult {
  final Map<dynamic, dynamic> simInfo;
  final int availableSims;
  final bool simDetectionEnabled;
  final String status;
  final String? error;

  SimInfoResult({
    required this.simInfo,
    required this.availableSims,
    required this.simDetectionEnabled,
    required this.status,
    this.error,
  });
}