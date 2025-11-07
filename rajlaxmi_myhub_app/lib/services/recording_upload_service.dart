import 'dart:io';
import 'package:call_log/call_log.dart';

class RecordingUploadService {
  Future<File?> getRecordingFile(String? recordingPath) async {
    if (recordingPath == null) return null;

    final recordingFile = File(recordingPath);
    final bool fileExists = await recordingFile.exists();

    if (!fileExists || (await recordingFile.length()) == 0) return null;

    return recordingFile;
  }

  CallLogEntry? getLatestCall(List<CallLogEntry> callHistory, String number) {
    final recentCalls = callHistory.where((entry) => entry.number == number).toList();
    if (recentCalls.isEmpty) return null;

    recentCalls.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    return recentCalls.first;
  }

  Map<String, dynamic> createCallDataWithSim({
    required Map<String, dynamic> baseCallData,
    required String simInfo,
    required int availableSims,
    required bool simDetectionEnabled,
    required Map<dynamic, dynamic> simDetails,
    required String defaultSim,
  }) {
    return {
      ...baseCallData,
      'sim_info': simInfo,
      'available_sims': availableSims,
      'sim_detection_enabled': simDetectionEnabled,
      'sim_details': simDetails,
      'default_sim': defaultSim,
    };
  }
}