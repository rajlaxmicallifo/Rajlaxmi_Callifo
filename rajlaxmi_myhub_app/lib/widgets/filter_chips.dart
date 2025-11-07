import 'package:flutter/material.dart';
import 'package:call_log/call_log.dart';

class FilterChips extends StatelessWidget {
  final List<CallLogEntry> callHistory;
  final String selectedFilter;
  final ValueChanged<String> onFilterChanged;

  const FilterChips({
    super.key,
    required this.callHistory,
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final counts = _getCallCounts();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: counts.entries.map((entry) {
          return _buildFilterChip(entry.key, entry.value);
        }).toList(),
      ),
    );
  }

  Map<String, int> _getCallCounts() {
    return {
      'All': callHistory.length,
      'Incoming': callHistory.where((c) => c.callType == CallType.incoming).length,
      'Outgoing': callHistory.where((c) => c.callType == CallType.outgoing).length,
      'Missed': callHistory.where((c) => c.callType == CallType.missed).length,
    };
  }

  Widget _buildFilterChip(String filter, int count) {
    final selected = selectedFilter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: ChoiceChip(
        label: Text('$filter ($count)'),
        selected: selected,
        onSelected: (_) => onFilterChanged(filter),
        selectedColor: Colors.blueAccent,
        backgroundColor: Colors.grey[300],
      ),
    );
  }
}