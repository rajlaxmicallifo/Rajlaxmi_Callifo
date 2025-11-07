import 'package:flutter/material.dart';

class SimSelectionDialog extends StatelessWidget {
  final String selectedSimForCall;
  final ValueChanged<String> onSimSelected;

  const SimSelectionDialog({
    super.key,
    required this.selectedSimForCall,
    required this.onSimSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Select SIM Card'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Choose which SIM to use for this call:'),
          const SizedBox(height: 16),
          _buildSimOption(context, 'Use Default SIM', selectedSimForCall, Icons.phone,
              'Current default: ${selectedSimForCall.toUpperCase()}'),
          const SizedBox(height: 12),
          _buildSimOption(context, 'SIM 1', 'sim1', Icons.sim_card, 'Use SIM 1 for this call'),
          const SizedBox(height: 12),
          _buildSimOption(context, 'SIM 2', 'sim2', Icons.sim_card, 'Use SIM 2 for this call'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildSimOption(BuildContext context, String title, String value, IconData icon, String description) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
        onSimSelected(value);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.shade200),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.blue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}