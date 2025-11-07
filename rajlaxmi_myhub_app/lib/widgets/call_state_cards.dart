import 'package:flutter/material.dart';
import '../features/call_manager/recording_service.dart';
import '../managers/call_manager_state.dart';

class CallStateCards extends StatelessWidget {
  final CallManagerState state;
  final RecordingService recordingService;

  const CallStateCards({
    super.key,
    required this.state,
    required this.recordingService,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.incomingCall && !state.isCallAnswered)
          _buildCallCard('Incoming Call - Ringing', Colors.yellow[100]!, Icons.call_received),
        if (state.incomingCall && state.isCallAnswered)
          _buildCallCard('Incoming Call - Answered & Recording', Colors.green[100]!, Icons.call_received),
        if (state.outgoingCall && state.isOutgoingDialing)
          _buildCallCard('Outgoing Call - Calling...', Colors.orange[100]!, Icons.call_made),
        if (state.outgoingCall && state.isCallAnswered)
          _buildCallCard('Outgoing Call - Connected & Recording', Colors.green[100]!, Icons.call_made),
        if (recordingService.isRecording)
          _buildCallCard('MP3 RECORDING ACTIVE', Colors.red[50]!, Icons.mic),
        if (state.isOutgoingDialing || state.isInCall)
          _buildCallStateInfoCard(),
      ],
    );
  }

  Widget _buildCallCard(String title, Color color, IconData icon) {
    return Card(
      color: color,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: icon == Icons.mic ? Colors.red : Colors.green),
        title: Text('$title: ${state.phoneNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: recordingService.isRecording ? const Text('MP3 recording in progress...') : null,
        trailing: title.contains('Recording') ? const Icon(Icons.mic, color: Colors.red) : null,
      ),
    );
  }

  Widget _buildCallStateInfoCard() {
    return Card(
      color: Colors.blue[50],
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.info, color: Colors.blue),
        title: const Text('Call State & SIM Info', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(_getCallStateInfo()),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              recordingService.isRecording ? Icons.mic : Icons.mic_off,
              color: recordingService.isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.sim_card,
              color: state.simDetectionEnabled ? Colors.green : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  String _getCallStateInfo() {
    if (!state.isInCall) {
      if (state.isOutgoingDialing) {
        return "Calling... with ${state.selectedSimForCall.toUpperCase()} - Waiting for answer";
      }
      return "No active call";
    }

    final callType = state.wasIncomingCall ? "Incoming" : "Outgoing";
    final simInfo = state.wasIncomingCall ? "Incoming" : state.selectedSimForCall.toUpperCase();
    final recordingStatus = recordingService.isRecording ? "MP3 RECORDING ACTIVE" : "No recording";

    return "Call with ${state.currentCallNumber} - Type: $callType - SIM: $simInfo - $recordingStatus";
  }
}