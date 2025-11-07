import 'dart:async';
import 'dart:io';
import 'package:call_log/call_log.dart';
import 'package:flutter/material.dart';
import 'package:phone_state/phone_state.dart';
import 'package:intl/intl.dart';

import '../features/call_manager/recording_service.dart';
import 'Call_Data/call_service.dart';
import 'features/sim_detection/sim_management_widgets.dart';
import 'managers/call_manager_state.dart';
import 'managers/call_state_manager.dart';
import 'services/sim_service.dart';
import 'services/call_history_service.dart';
import 'services/call_operations_service.dart';
import 'services/recording_upload_service.dart';
import 'services/permission_service.dart';
import 'widgets/call_state_cards.dart';
import 'widgets/search_field.dart';
import 'widgets/filter_chips.dart';
import 'widgets/sim_selection_dialog.dart';
import 'widgets/recordings_dialog.dart';

class CallManagerPage extends StatefulWidget {
  final String authToken;
  final int staffId;

  const CallManagerPage({
    super.key,
    required this.authToken,
    this.staffId = 1,
  });

  @override
  State<CallManagerPage> createState() => _CallManagerPageState();
}

class _CallManagerPageState extends State<CallManagerPage> {
  // Services
  final CallService _callService = CallService();
  final RecordingService _recordingService = RecordingService();
  final SimService _simService = SimService();
  final CallHistoryService _callHistoryService = CallHistoryService();
  final CallOperationsService _callOperationsService = CallOperationsService();
  final RecordingUploadService _recordingUploadService = RecordingUploadService();
  final CallStateManager _callStateManager = CallStateManager();

  // State
  final CallManagerState _state = CallManagerState();
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _callStateManager.dispose();
    _recordingService.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    _callService.setToken(widget.authToken);
    await _recordingService.initializeRecorder();
    await _getSimInfo();
    await _requestPermissions();
  }

  // Permission Management
  Future<void> _requestPermissions() async {
    final hasPermission = await PermissionService.requestCallPermissions();
    if (hasPermission) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _listenPhoneState();
        _fetchCallHistory();
      });
    } else {
      _showSnackBar('Phone permission is required to access call history.', Colors.orange);
    }
  }

  // SIM Management
  Future<void> _getSimInfo() async {
    setState(() => _state.simStatus = 'Loading SIM info...');
    final result = await _simService.getSimInfo();

    setState(() {
      _state.simInfo = result.simInfo;
      _state.availableSims = result.availableSims;
      _state.simDetectionEnabled = result.simDetectionEnabled;
      _state.simStatus = result.status;

      if (_state.availableSims == 1) {
        _state.selectedSimForCall = 'sim1';
      }
    });
  }

  Future<void> _performSimChange(String newSim) async {
    setState(() {
      _state.isChangingSim = true;
      _state.simChangeStatus = 'Changing to ${newSim.toUpperCase()}...';
    });

    final finalSim = await _simService.performSimChange(newSim, _state.simInfo);

    setState(() {
      _state.selectedSimForCall = finalSim;
      _state.isChangingSim = false;
      _state.simChangeStatus = '';
    });

    _showSnackBar('Default SIM changed to ${finalSim.toUpperCase()}', Colors.green);
    await _getSimInfo();
  }

  // Call Management - FIXED SIM 2 SELECTION
  Future<void> _makeCallWithSim(String number) async {
    if (number.isEmpty) {
      _showSnackBar('Please enter a phone number', Colors.red);
      return;
    }

    try {
      if (_state.availableSims > 1 && _state.simDetectionEnabled) {
        await showDialog(
          context: context,
          builder: (context) => SimSelectionDialog(
            selectedSimForCall: _state.selectedSimForCall,
            onSimSelected: (simSlot) => _makeCallWithSpecificSim(number, simSlot),
          ),
        );
      } else {
        await _makeCallWithSpecificSim(number, _state.selectedSimForCall);
      }
    } catch (e) {
      _showSnackBar('Error making call: $e', Colors.red);
    }
  }

  // FIXED: Enhanced SIM mapping for outgoing calls
  Future<void> _makeCallWithSpecificSim(String number, String simSlot) async {
    print("📞 Making call with SIM: $simSlot to $number");

    // Store the SIM selection BEFORE making the call
    final previousSim = _state.selectedSimForCall;
    if (simSlot != _state.selectedSimForCall) {
      setState(() => _state.selectedSimForCall = simSlot);
    }

    try {
      await _callOperationsService.makeCallWithSpecificSim(number, simSlot);

      // IMPORTANT: Update SIM mapping immediately after call
      _updateSimMappingForOutgoingCall(number, simSlot);

      _showSnackBar('Calling $number with ${simSlot.toUpperCase()}', Colors.blue);
    } catch (e) {
      print("❌ Error making call with specific SIM: $e");
      // Revert SIM selection if call fails
      if (simSlot != previousSim) {
        setState(() => _state.selectedSimForCall = previousSim);
      }
      await _callOperationsService.makeCall(number);
    }
  }

  // NEW: Enhanced SIM mapping for outgoing calls
  void _updateSimMappingForOutgoingCall(String number, String simSlot) {
    print("📝 Mapping outgoing call to SIM: $number -> $simSlot");

    // Create a temporary call entry for immediate mapping
    final tempCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _state.callSimMapping[tempCallId] = simSlot;

    // Force refresh to see the change immediately
    _applyFilter();

    print("✅ SIM mapping updated. Total mappings: ${_state.callSimMapping.length}");
  }

  // Call History Management
  Future<void> _fetchCallHistory() async {
    if (_state.isFetching) return;
    setState(() => _state.isFetching = true);

    try {
      _state.callHistory = await _callHistoryService.fetchCallHistory();
      _applyFilter();

      // Debug: Print SIM mapping status
      _printSimMappingDebugInfo();
    } catch (e) {
      _showSnackBar('Error fetching call history: $e', Colors.red);
    } finally {
      setState(() => _state.isFetching = false);
    }
  }

  void _applyFilter() {
    setState(() {
      _state.filteredCalls = _callHistoryService.applyFilters(
        callHistory: _state.callHistory,
        searchText: _searchController.text,
        selectedFilter: _state.selectedFilter,
        selectedSimFilter: _state.selectedSimForFilter,
        callSimMapping: _state.callSimMapping,
        selectedSimForCall: _state.selectedSimForCall,
      );
    });

    print("🔍 Filter applied: ${_state.selectedSimForFilter}, Showing: ${_state.filteredCalls.length} calls");
  }

  void _changeSimFilter(String simFilter) {
    setState(() => _state.selectedSimForFilter = simFilter);
    _applyFilter();
  }

  void _changeCallFilter(String filter) {
    setState(() => _state.selectedFilter = filter);
    _applyFilter();
  }

  // Phone State Management - FIXED SIM detection
  void _listenPhoneState() {
    try {
      _callStateManager.setPhoneSubscription(
        PhoneState.stream.listen((PhoneState state) async {
          final number = state.number ?? '';
          final status = state.status;

          print("📞 Phone State: $status, Number: $number, Current SIM: ${_state.selectedSimForCall}");

          setState(() {
            _state.phoneNumber = number;
            _state.lastCallStatus = status;
          });

          switch (status) {
            case PhoneStateStatus.CALL_INCOMING:
              await _handleIncomingCall(number);
              break;
            case PhoneStateStatus.CALL_STARTED:
              await _handleCallStarted(number);
              break;
            case PhoneStateStatus.CALL_ENDED:
              await _handleCallEnded(number);
              break;
            default:
              break;
          }

          _fetchCallHistory();
        }),
      );
    } catch (e) {
      _showSnackBar('Phone state listener failed: $e', Colors.red);
    }
  }

  Future<void> _handleIncomingCall(String number) async {
    print("🔔 INCOMING CALL from: $number");
    _resetCallState();

    setState(() {
      _state.wasIncomingCall = true;
      _state.incomingCall = true;
      _state.currentCallNumber = number;
    });

    // Map incoming call
    _updateSimMappingForIncomingCall(number);
    await _registerCallImmediately(number);
  }

  // NEW: Enhanced SIM mapping for incoming calls
  void _updateSimMappingForIncomingCall(String number) {
    print("📝 Mapping incoming call: $number -> incoming");
    final tempCallId = DateTime.now().millisecondsSinceEpoch.toString();
    _state.callSimMapping[tempCallId] = 'incoming';
  }

  Future<void> _handleCallStarted(String number) async {
    _callStateManager.cancelAnswerDetectionTimer();

    if (_state.lastCallStatus == PhoneStateStatus.CALL_INCOMING) {
      _handleCallAnswered(number, isIncoming: true);
    } else if (!_state.isOutgoingDialing && !_state.isCallAnswered) {
      _handleOutgoingDialing(number);
    } else if (_state.isOutgoingDialing && !_state.isCallAnswered) {
      _handleCallAnswered(number, isIncoming: false);
    }
  }

  void _handleOutgoingDialing(String number) {
    setState(() {
      _state.isOutgoingDialing = true;
      _state.wasIncomingCall = false;
      _state.outgoingCall = true;
      _state.currentCallNumber = number;
    });

    _state.callStartTime = DateTime.now();

    _callStateManager.setAnswerDetectionTimer(Timer(const Duration(seconds: 3), () {
      if (_state.isOutgoingDialing && !_state.isCallAnswered && mounted) {
        _handleCallAnswered(number, isIncoming: false);
      }
    }));
  }

  void _handleCallAnswered(String number, {required bool isIncoming}) {
    setState(() {
      _state.isCallAnswered = true;
      _state.isOutgoingDialing = false;
      _state.wasIncomingCall = isIncoming;
      _state.isInCall = true;

      if (isIncoming) {
        _state.incomingCall = true;
        _state.outgoingCall = false;
      } else {
        _state.outgoingCall = true;
        _state.incomingCall = false;
      }
    });

    _startAutomaticMP3Recording(number, isIncoming);
  }

  Future<void> _handleCallEnded(String number) async {
    print("📞 CALL ENDED: $number, Answered: ${_state.isCallAnswered}, SIM: ${_state.selectedSimForCall}");
    _callStateManager.cancelAnswerDetectionTimer();

    if (_recordingService.isRecording) {
      await _stopAutomaticMP3Recording();
    }

    if (_state.isCallAnswered) {
      await _uploadCallWithMP3Recording(number);
    } else if (_state.wasIncomingCall) {
      await _uploadCallData(number, 'missed', 0);
    }

    _resetCallState();
  }

  void _resetCallState() {
    _callStateManager.cancelAnswerDetectionTimer();

    setState(() {
      _state.isInCall = false;
      _state.isCallAnswered = false;
      _state.wasIncomingCall = false;
      _state.isOutgoingDialing = false;
      _state.incomingCall = false;
      _state.outgoingCall = false;
      _state.currentCallNumber = null;
      _state.callStartTime = null;
    });
  }

  // NEW: Debug method to print SIM mapping info
  void _printSimMappingDebugInfo() {
    print("📊 SIM MAPPING DEBUG INFO:");
    print("   - Total calls: ${_state.callHistory.length}");
    print("   - SIM mappings: ${_state.callSimMapping.length}");

    final sim1Count = _state.callSimMapping.values.where((sim) => sim == 'sim1').length;
    final sim2Count = _state.callSimMapping.values.where((sim) => sim == 'sim2').length;
    final incomingCount = _state.callSimMapping.values.where((sim) => sim == 'incoming').length;

    print("   - SIM 1 calls: $sim1Count");
    print("   - SIM 2 calls: $sim2Count");
    print("   - Incoming calls: $incomingCount");

    // Print recent mappings
    if (_state.callSimMapping.isNotEmpty) {
      print("   - Recent mappings:");
      final recentEntries = _state.callSimMapping.entries.take(500);
      for (final entry in recentEntries) {
        print("     ${entry.key}: ${entry.value}");
      }
    }
  }

  // Recording & Upload Management
  Future<void> _startAutomaticMP3Recording(String phoneNumber, bool isIncoming) async {
    final success = await _recordingService.startAutomaticRecording(phoneNumber, isIncoming);
    if (success) {
      _showSnackBar('Automatic MP3 recording started', Colors.green);
    } else {
      _showSnackBar('Failed to start MP3 recording', Colors.red);
    }
  }

  Future<void> _stopAutomaticMP3Recording() async {
    final result = await _recordingService.stopAutomaticRecording();
    if (result.success) {
      _showSnackBar('Automatic MP3 recording stopped', Colors.blue);
    } else {
      _showSnackBar('Error stopping recording: ${result.error}', Colors.red);
    }
  }

  Future<void> _uploadCallWithMP3Recording(String number) async {
    try {
      final File? recordingFile = await _recordingUploadService.getRecordingFile(
        _recordingService.currentRecordingPath,
      );

      final CallLogEntry? latestCall = _recordingUploadService.getLatestCall(
        _state.callHistory, number,
      );

      if (latestCall == null) return;

      final callTypeString = _state.wasIncomingCall ? 'incoming' : 'outgoing';
      final simInfo = _state.wasIncomingCall ? 'incoming' : _state.selectedSimForCall;
      final callId = latestCall.timestamp.toString();

      if (_state.uploadInProgress.contains(callId)) return;
      _state.uploadInProgress.add(callId);

      final baseCallData = _callService.createCallData(
        phoneNumber: number,
        callType: callTypeString,
        duration: latestCall.duration ?? 0,
        callId: callId,
        startTime: DateTime.fromMillisecondsSinceEpoch(latestCall.timestamp!).toIso8601String(),
        endTime: DateTime.now().toIso8601String(),
        staffId: widget.staffId,
        callerName: latestCall.name ?? '',
      );

      final callData = _recordingUploadService.createCallDataWithSim(
        baseCallData: baseCallData,
        simInfo: simInfo,
        availableSims: _state.availableSims,
        simDetectionEnabled: _state.simDetectionEnabled,
        simDetails: _state.simInfo,
        defaultSim: _state.selectedSimForCall,
      );

      final result = recordingFile != null
          ? await _callService.uploadCallWithRecording(callData: callData, recordingFile: recordingFile)
          : await _callService.uploadCall(logData: callData);

      if (result.contains('successfully')) {
        _state.uploadedCallIds.add(callId);
        _showSnackBar('Call ${recordingFile != null ? 'recorded and ' : ''}uploaded (SIM: ${simInfo.toUpperCase()})', Colors.green);
      } else {
        _showSnackBar('Upload failed', Colors.red);
      }

      _state.uploadInProgress.remove(callId);
    } catch (e) {
      _showSnackBar('Upload error: $e', Colors.red);
    }
  }

  Future<void> _uploadCallData(String number, String callType, int duration) async {
    try {
      final callId = DateTime.now().millisecondsSinceEpoch.toString();
      if (_state.uploadedCallIds.contains(callId)) return;

      final baseCallData = _callService.createCallData(
        phoneNumber: number,
        callType: callType,
        duration: duration,
        callId: callId,
        startTime: DateTime.now().toIso8601String(),
        staffId: widget.staffId,
        callerName: '',
      );

      final callData = _recordingUploadService.createCallDataWithSim(
        baseCallData: baseCallData,
        simInfo: 'incoming',
        availableSims: _state.availableSims,
        simDetectionEnabled: _state.simDetectionEnabled,
        simDetails: _state.simInfo,
        defaultSim: _state.selectedSimForCall,
      );

      final result = await _callService.uploadCall(logData: callData);
      if (result.contains('successfully')) {
        _state.uploadedCallIds.add(callId);
      }
    } catch (e) {
      print("Error uploading call data: $e");
    }
  }

  Future<void> _registerCallImmediately(String number) async {
    try {
      await _callService.registerIncomingCallImmediately(
        phoneNumber: number,
        staffId: widget.staffId,
        callerName: '',
      );
    } catch (e) {
      print("Error in immediate registration: $e");
    }
  }

  // Manual Recording Management
  Future<void> _uploadManualMP3Recording() async {
    final recordings = await _recordingService.getRecordedCallsWithInfo();
    if (recordings.isEmpty) {
      _showSnackBar('No MP3 recordings found to upload', Colors.orange);
      return;
    }

    final recentRecording = recordings.first;
    final file = recentRecording.file;

    if (await file.exists()) {
      _showSnackBar('Starting manual MP3 upload...', Colors.blue);

      String phoneNumber = 'Unknown';
      try {
        final filename = recentRecording.fileName;
        final parts = filename.split('_');
        if (parts.length >= 3) {
          phoneNumber = parts[2].replaceAll('_', '');
        }
      } catch (e) {
        print('Error parsing phone number from filename: $e');
      }

      final baseCallData = _callService.createCallData(
        phoneNumber: phoneNumber.isNotEmpty ? phoneNumber : recentRecording.phoneNumber,
        callType: recentRecording.callType,
        duration: 0,
        callId: 'manual_${DateTime.now().millisecondsSinceEpoch}',
        startTime: DateTime.now().toIso8601String(),
        staffId: widget.staffId,
        callerName: '',
      );

      final callData = _recordingUploadService.createCallDataWithSim(
        baseCallData: baseCallData,
        simInfo: 'manual_upload',
        availableSims: _state.availableSims,
        simDetectionEnabled: _state.simDetectionEnabled,
        simDetails: _state.simInfo,
        defaultSim: _state.selectedSimForCall,
      );

      final result = await _callService.uploadCallWithRecording(
        callData: callData,
        recordingFile: file,
      );

      if (result.contains('successfully')) {
        _showSnackBar('MP3 Recording uploaded successfully!', Colors.green);
      } else {
        _showSnackBar('MP3 Upload failed: $result', Colors.red);
      }
    }
  }

  Future<void> _showRecordingsDialog() async {
    final recordings = await _recordingService.getRecordedCallsWithInfo();
    if (recordings.isEmpty) {
      _showSnackBar('No MP3 recordings found', Colors.orange);
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => RecordingsDialog(
        recordings: recordings,
        onUploadPressed: () {
          Navigator.pop(context);
          _uploadManualMP3Recording();
        },
      ),
    );
  }

  // NEW: Method to get SIM call counts for filter chips
  Map<String, int> _getSimCallCounts() {
    final callHistoryService = CallHistoryService();
    final counts = {
      'all': _state.callHistory.length,
      'sim1': 0,
      'sim2': 0,
    };

    for (final entry in _state.callHistory) {
      final callSim = callHistoryService.getSimForCall(
        entry: entry,
        callSimMapping: _state.callSimMapping,
        selectedSimForCall: _state.selectedSimForCall,
      );

      if (callSim == 'sim1') {
        counts['sim1'] = counts['sim1']! + 1;
      } else if (callSim == 'sim2') {
        counts['sim2'] = counts['sim2']! + 1;
      }
    }

    print('📊 SIM Call Counts: $counts');
    return counts;
  }

  // NEW: Test method to manually map calls to SIM 2
  void _testSim2Mapping() {
    if (_state.callHistory.isNotEmpty) {
      int mappedCount = 0;
      for (int i = 0; i < _state.callHistory.length && i < 500; i++) {
        final entry = _state.callHistory[i];
        final callId = entry.timestamp.toString();
        _state.callSimMapping[callId] = 'sim2';
        mappedCount++;
        print('🧪 Test mapping: ${entry.number} -> SIM 2');
      }
      _applyFilter();
      _showSnackBar('Test: Mapped $mappedCount calls to SIM 2', Colors.orange);
    }
  }

  // UI Helpers
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  // Helper methods for building call items
  Widget _buildCallIcon(CallLogEntry entry) {
    final (iconColor, iconData) = _getCallTypeInfo(entry);
    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(iconData, color: iconColor),
    );
  }

  (Color, IconData) _getCallTypeInfo(CallLogEntry entry) {
    return switch (entry.callType) {
      CallType.missed => (Colors.red, Icons.call_missed),
      CallType.incoming => (Colors.green, Icons.call_received),
      CallType.outgoing => (Colors.orange, Icons.call_made),
      _ => (Colors.grey, Icons.call),
    };
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final DateTime ts = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('dd/MM/yyyy HH:mm').format(ts);
  }

  Color _getSimColor(String callSim) {
    return switch (callSim) {
      'sim1' => Colors.blue,
      'sim2' => Colors.green,
      _ => Colors.grey,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Call Manager', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.audio_file, color: Colors.blue),
            onPressed: _showRecordingsDialog,
            tooltip: 'View Recordings',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.green),
            onPressed: () {
              _fetchCallHistory();
              _testSim2Mapping();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: <Widget>[
            // CALL STATUS CARDS
            CallStateCards(
              state: _state,
              recordingService: _recordingService,
            ),

            const SizedBox(height: 12),

            // SEARCH FIELD
            SearchField(
              controller: _searchController,
              onCallPressed: () => _makeCallWithSim(_searchController.text.trim()),
              onChanged: (_) => _applyFilter(),
            ),

            const SizedBox(height: 12),

            // SCROLLABLE CONTENT (Filters + Call History)
            Expanded(
              child: CustomScrollView(
                slivers: [
                  // Call Type Filter Chips
                  SliverToBoxAdapter(
                    child: FilterChips(
                      callHistory: _state.callHistory,
                      selectedFilter: _state.selectedFilter,
                      onFilterChanged: _changeCallFilter,
                    ),
                  ),

                  // SIM Filter Chips (if available) - CENTERED
                  if (_state.availableSims > 1)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Centered SIM filter chips
                            Center(
                              child: SimFilterChips(
                                selectedSimFilter: _state.selectedSimForFilter,
                                onSimFilterChanged: _changeSimFilter,
                                simCallCounts: _getSimCallCounts(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Add some spacing before call list
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),

                  // Results header
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        children: [
                          Text(
                            'Recent Calls',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[800],
                            ),
                          ),
                          const Spacer(),
                          if (_state.isFetching)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          const SizedBox(width: 8),
                          Text(
                            '${_state.filteredCalls.length} calls',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Call History List
                  if (_state.filteredCalls.isEmpty)
                    SliverToBoxAdapter(
                      child: Container(
                        height: 200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.phone_disabled,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No calls found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try changing your filters or make some calls',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final entry = _state.filteredCalls[index];
                          final callHistoryService = CallHistoryService();
                          final callSim = callHistoryService.getSimForCall(
                            entry: entry,
                            callSimMapping: _state.callSimMapping,
                            selectedSimForCall: _state.selectedSimForCall,
                          );

                          return Card(
                            elevation: 1,
                            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            child: ListTile(
                              leading: _buildCallIcon(entry),
                              title: Text(
                                entry.name ?? entry.number ?? 'Unknown',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${entry.number ?? ''} • ${entry.duration ?? 0}s • ${_formatTime(entry.timestamp)}'),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _getSimColor(callSim).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _getSimColor(callSim), width: 1),
                                    ),
                                    child: Text(
                                      callSim == 'incoming' ? 'IN' : callSim.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: _getSimColor(callSim),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              trailing: _state.uploadedCallIds.contains(entry.timestamp.toString())
                                  ? const Icon(Icons.cloud_done, color: Colors.green, size: 16)
                                  : null,
                              onTap: () => _makeCallWithSim(entry.number ?? ''),
                            ),
                          );
                        },
                        childCount: _state.filteredCalls.length,
                      ),
                    ),



                ],
              ),
            ),
          ],
        ),
      ),



    );
  }
}