import 'package:call_log/call_log.dart';

class CallHistoryService {
  Future<List<CallLogEntry>> fetchCallHistory() async {
    try {
      final Iterable<CallLogEntry> logs = await CallLog.get();
      return logs.toList();
    } catch (e) {
      throw Exception('Error fetching call history: $e');
    }
  }

  List<CallLogEntry> applyFilters({
    required List<CallLogEntry> callHistory,
    required String searchText,
    required String selectedFilter,
    required String selectedSimFilter,
    required Map<String, String> callSimMapping,
    required String selectedSimForCall,
  }) {
    final filteredCalls = callHistory.where((entry) {
      final bool matchesSearch = _matchesSearch(entry, searchText);
      final bool matchesFilter = _matchesCallTypeFilter(entry, selectedFilter);
      final bool matchesSimFilter = _matchesSimFilter(
          entry, selectedSimFilter, callSimMapping, selectedSimForCall
      );

      // Debug logging for SIM 2 filter
      if (selectedSimFilter == 'sim2') {
        final callSim = getSimForCall(
          entry: entry,
          callSimMapping: callSimMapping,
          selectedSimForCall: selectedSimForCall,
        );
        print('🔍 SIM2 Filter - Call: ${entry.number}, Type: ${entry.callType}, Assigned SIM: $callSim, Matches: ${callSim == "sim2"}');
      }

      return matchesSearch && matchesFilter && matchesSimFilter;
    }).toList();

    print('🎯 Filter Results - SIM: $selectedSimFilter, Total: ${callHistory.length}, Filtered: ${filteredCalls.length}');
    return filteredCalls;
  }

  String getSimForCall({
    required CallLogEntry entry,
    required Map<String, String> callSimMapping,
    required String selectedSimForCall,
  }) {
    final callId = entry.timestamp.toString();

    // Check if we have a specific mapping for this call
    if (callSimMapping.containsKey(callId)) {
      return callSimMapping[callId]!;
    }

    // For unmapped calls, use logic based on call type
    if (entry.callType == CallType.incoming) {
      return 'incoming';
    } else {
      // For outgoing calls without specific mapping, use current SIM selection
      return selectedSimForCall;
    }
  }

  bool _matchesSearch(CallLogEntry entry, String searchText) {
    final name = entry.name ?? '';
    final number = entry.number ?? '';
    return searchText.isEmpty ||
        name.toLowerCase().contains(searchText.toLowerCase()) ||
        number.contains(searchText);
  }

  bool _matchesCallTypeFilter(CallLogEntry entry, String selectedFilter) {
    return switch (selectedFilter) {
      'All' => true,
      'Incoming' => entry.callType == CallType.incoming,
      'Outgoing' => entry.callType == CallType.outgoing,
      'Missed' => entry.callType == CallType.missed,
      _ => true,
    };
  }

  bool _matchesSimFilter(
      CallLogEntry entry,
      String selectedSimFilter,
      Map<String, String> callSimMapping,
      String selectedSimForCall,
      ) {
    if (selectedSimFilter == 'all') return true;

    final callSim = getSimForCall(
      entry: entry,
      callSimMapping: callSimMapping,
      selectedSimForCall: selectedSimForCall,
    );

    return callSim == selectedSimFilter;
  }

  void updateCallSimMapping({
    required List<CallLogEntry> callHistory,
    required String number,
    required String simSlot,
    required Map<String, String> callSimMapping,
  }) {
    final recentCalls = callHistory.where((entry) => entry.number == number).toList();
    if (recentCalls.isNotEmpty) {
      recentCalls.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
      final latestCall = recentCalls.first;
      final callId = latestCall.timestamp.toString();
      callSimMapping[callId] = simSlot;
      print('✅ SIM Mapping Updated: $number -> $simSlot (CallID: $callId)');
    } else {
      print('⚠️ No recent call found for number: $number');
    }
  }
}