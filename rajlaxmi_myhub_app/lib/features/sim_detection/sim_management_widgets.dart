import 'package:flutter/material.dart';

import '../../managers/call_manager_state.dart';

class SimFilterChips extends StatelessWidget {
  final String selectedSimFilter;
  final ValueChanged<String> onSimFilterChanged;
  final Map<String, int> simCallCounts;

  const SimFilterChips({
    super.key,
    required this.selectedSimFilter,
    required this.onSimFilterChanged,
    required this.simCallCounts,
  });

  @override
  Widget build(BuildContext context) {
    final List<SimOption> simOptions = [
      SimOption(label: 'SIM 1', value: 'sim1', count: simCallCounts['sim1'] ?? 0),
      SimOption(label: 'SIM 2', value: 'sim2', count: simCallCounts['sim2'] ?? 0),
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter by SIM Card:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: simOptions.map((option) {
                  return _buildSimChip(option);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimChip(SimOption option) {
    final selected = selectedSimFilter == option.value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text('${option.label} (${option.count})'),
        selected: selected,
        onSelected: (_) => onSimFilterChanged(option.value),
        selectedColor: option.value == 'sim1' ? Colors.blueAccent : Colors.greenAccent,
        backgroundColor: Colors.grey[300],
        labelStyle: TextStyle(
          color: selected ? Colors.white : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

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
        title: const Text('', style: TextStyle(fontWeight: FontWeight.bold,height: 0,)),
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
          Text('Selected SIM: ${state.selectedSimForCall.toUpperCase()}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: state.selectedSimForCall == 'sim1' ? Colors.blue : Colors.green,
              )),
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
          icon: Icon(Icons.sim_card,
              size: 20,
              color: state.selectedSimForCall == 'sim1' ? Colors.blue : Colors.green),
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

class SimOption {
  final String label;
  final String value;
  final int count;

  const SimOption({
    required this.label,
    required this.value,
    required this.count,
  });
}