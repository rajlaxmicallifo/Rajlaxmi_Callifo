import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import '../managers/call_manager_state.dart';
import '../services/call_history_service.dart';

class CallHistoryList extends StatelessWidget {
  final CallManagerState state;
  final Map<String, String> callSimMapping;
  final String selectedSimForCall;
  final Set<String> uploadedCallIds;
  final AsyncCallback onRefresh;
  final ValueChanged<String> onCallPressed;

  const CallHistoryList({
    super.key,
    required this.state,
    required this.callSimMapping,
    required this.selectedSimForCall,
    required this.uploadedCallIds,
    required this.onRefresh,
    required this.onCallPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView.builder(
          itemCount: state.filteredCalls.length,
          itemBuilder: (context, index) {
            return _buildCallItem(state.filteredCalls[index]);
          },
        ),
      ),
    );
  }

  Widget _buildCallItem(CallLogEntry entry) {
    final callHistoryService = CallHistoryService();
    final callSim = callHistoryService.getSimForCall(
      entry: entry,
      callSimMapping: callSimMapping,
      selectedSimForCall: selectedSimForCall,
    );

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: _buildCallIcon(entry),
        title: _buildCallTitle(entry),
        subtitle: _buildCallSubtitle(entry, callSim),
        trailing: _buildCallTrailing(entry),
        onTap: () => onCallPressed(entry.number ?? ''),
      ),
    );
  }

  Widget _buildCallIcon(CallLogEntry entry) {
    final (iconColor, iconData) = _getCallTypeInfo(entry);
    return CircleAvatar(
      backgroundColor: iconColor.withOpacity(0.2),
      child: Icon(iconData, color: iconColor),
    );
  }

  Widget _buildCallTitle(CallLogEntry entry) {
    return Text(
      entry.name ?? entry.number ?? 'Unknown',
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
    );
  }

  Widget _buildCallSubtitle(CallLogEntry entry, String callSim) {
    final time = _formatTime(entry.timestamp);
    final simLabel = callSim == 'incoming' ? 'IN' : callSim.toUpperCase();
    final simColor = _getSimColor(callSim);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${entry.number ?? ''} • ${entry.duration ?? 0}s • $time'),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: simColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: simColor, width: 1),
          ),
          child: Text(
            simLabel,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: simColor,
            ),
          ),
        ),
      ],
    );
  }

  Icon? _buildCallTrailing(CallLogEntry entry) {
    return uploadedCallIds.contains(entry.timestamp.toString())
        ? const Icon(Icons.cloud_done, color: Colors.green, size: 16)
        : null;
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
}