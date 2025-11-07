import 'package:flutter/material.dart';
import '../managers/call_manager_state.dart';

class SimInfoCard extends StatelessWidget {
  final CallManagerState state;
  final VoidCallback onRefresh;
  final VoidCallback onChangeSim;

  const SimInfoCard({
    super.key,
    required this.state,
    required this.onRefresh,
    required this.onChangeSim,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.purple[50],
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.sim_card, color: Colors.purple),
        title: const Text('SIM Information', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: _buildSubtitle(),
        trailing: _buildTrailing(),
      ),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(state.simStatus),
        if (state.isChangingSim) ...[
          const SizedBox(height: 4),
          Text(state.simChangeStatus, style: const TextStyle(color: Colors.orange, fontSize: 12)),
        ],
        if (state.availableSims > 1) ...[
          const SizedBox(height: 4),
          Text('Default SIM: ${state.selectedSimForCall.toUpperCase()}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ],
    );
  }

  Widget _buildTrailing() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (state.availableSims > 1) _buildSimCountBadge(),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.sim_card, size: 20),
          onPressed: state.availableSims > 1 ? onChangeSim : null,
          tooltip: 'Change SIM Card',
        ),
        IconButton(
          icon: const Icon(Icons.refresh, size: 20),
          onPressed: onRefresh,
          tooltip: 'Refresh SIM Info',
        ),
      ],
    );
  }

  Widget _buildSimCountBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${state.availableSims} SIM',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Colors.purple,
        ),
      ),
    );
  }
}