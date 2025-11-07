import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'sim_detection_service.dart';

class SimDetectionPage extends StatefulWidget {
  const SimDetectionPage({super.key});

  @override
  State<SimDetectionPage> createState() => _SimDetectionPageState();
}

class _SimDetectionPageState extends State<SimDetectionPage> {
  String _selectedSim = 'all';
  List<Map<String, dynamic>> _callLogs = [];
  bool _isLoading = true;
  bool _permissionGranted = false;
  String _errorMessage = '';
  int _availableSims = 1;
  Map<dynamic, dynamic> _simInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _checkPermissions();
    await _getSimInfo();
  }

  Future<void> _checkPermissions() async {
    try {
      final status = await Permission.phone.request();

      if (status.isGranted) {
        setState(() {
          _permissionGranted = true;
        });
        await _loadActualCallLogs();
      } else {
        setState(() {
          _permissionGranted = false;
          _isLoading = false;
          _errorMessage = 'Call log permission is required to display your actual call history.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error checking permissions: $e';
      });
    }
  }

  Future<void> _getSimInfo() async {
    try {
      final result = await SimDetectionService.getSimInfo();
      if (result != null && result is Map) {
        setState(() {
          _simInfo = result;
          _availableSims = result['availableSims'] ?? 1;
        });
      }
    } catch (e) {
      print('Error getting SIM info: $e');
      setState(() {
        _availableSims = 1;
      });
    }
  }

  Future<void> _loadActualCallLogs() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      final dynamic result = await SimDetectionService.getCallLogs();

      List<Map<String, dynamic>> logs = [];
      if (result is List) {
        logs = result.map((item) {
          if (item is Map) {
            return Map<String, dynamic>.from(item);
          }
          return <String, dynamic>{};
        }).where((map) => map.isNotEmpty).toList();
      }

      setState(() {
        _callLogs = logs;
        _isLoading = false;

        if (logs.isEmpty) {
          _errorMessage = 'No call logs found on your device.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading call logs: $e\n\nPlease make sure call log permission is granted.';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCallLogs {
    if (_selectedSim == 'all') {
      return _callLogs;
    }
    return _callLogs.where((log) {
      final sim = log['sim']?.toString() ?? 'sim1';
      return sim == _selectedSim;
    }).toList();
  }

  Color _getCallTypeColor(String type) {
    switch (type) {
      case 'incoming':
        return Colors.green;
      case 'outgoing':
        return Colors.blue;
      case 'missed':
        return Colors.red;
      case 'rejected':
        return Colors.orange;
      case 'blocked':
        return Colors.purple;
      case 'voicemail':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  IconData _getCallTypeIcon(String type) {
    switch (type) {
      case 'incoming':
        return Icons.call_received;
      case 'outgoing':
        return Icons.call_made;
      case 'missed':
        return Icons.call_missed;
      case 'rejected':
        return Icons.block;
      case 'blocked':
        return Icons.block;
      case 'voicemail':
        return Icons.voicemail;
      default:
        return Icons.call;
    }
  }

  String _getCallTypeText(String type) {
    switch (type) {
      case 'incoming':
        return 'Incoming';
      case 'outgoing':
        return 'Outgoing';
      case 'missed':
        return 'Missed';
      case 'rejected':
        return 'Rejected';
      case 'blocked':
        return 'Blocked';
      case 'voicemail':
        return 'Voicemail';
      default:
        return 'Unknown';
    }
  }

  String _formatDuration(dynamic duration) {
    try {
      final seconds = int.tryParse(duration.toString()) ?? 0;
      if (seconds < 60) return '${seconds}s';
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (minutes < 60) {
        return '${minutes}m ${remainingSeconds}s';
      }
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      return '${hours}h ${remainingMinutes}m';
    } catch (e) {
      return '0s';
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      final millis = int.tryParse(timestamp.toString()) ?? 0;
      final date = DateTime.fromMillisecondsSinceEpoch(millis);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${_formatTime(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday ${_formatTime(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago ${_formatTime(date)}';
      } else {
        return '${date.day}/${date.month}/${date.year} ${_formatTime(date)}';
      }
    } catch (e) {
      return 'Unknown date';
    }
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSimInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 SIM Card Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.sim_card, color: Colors.purple),
                const SizedBox(width: 8),
                Text(
                  'Available SIMs: $_availableSims',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            if (_simInfo.isNotEmpty) ...[
              const SizedBox(height: 8),
              ..._simInfo.entries.map((entry) {
                if (entry.key.toString().contains('sim') && entry.value != null) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      '${entry.key}: ${entry.value}',
                      style: const TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  );
                }
                return const SizedBox.shrink();
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSimSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📱 Select SIM Card',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Filter call logs by SIM card:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildSimOption('All SIMs', 'all', Icons.sim_card)),
                const SizedBox(width: 12),
                Expanded(child: _buildSimOption('SIM 1', 'sim1', Icons.sim_card)),
                if (_availableSims > 1) ...[
                  const SizedBox(width: 12),
                  Expanded(child: _buildSimOption('SIM 2', 'sim2', Icons.sim_card)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimOption(String title, String value, IconData icon) {
    final isSelected = _selectedSim == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedSim = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade50 : Colors.grey.shade50,
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 24),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.blue : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCallLogItem(Map<String, dynamic> log) {
    final type = log['type']?.toString() ?? 'unknown';
    final sim = log['sim']?.toString() ?? 'sim1';
    final number = log['number']?.toString() ?? 'Unknown Number';
    final name = log['name']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 1,
      child: ListTile(
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _getCallTypeColor(type).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getCallTypeIcon(type),
            color: _getCallTypeColor(type),
            size: 20,
          ),
        ),
        title: Text(
          name.isNotEmpty ? name : number,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (name.isNotEmpty && number != 'Unknown Number') ...[
              const SizedBox(height: 4),
              Text(number, style: const TextStyle(fontSize: 14)),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatDate(log['date']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 12),
                Icon(Icons.timer, size: 12, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  _formatDuration(log['duration']),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                sim.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _getCallTypeText(type),
              style: TextStyle(
                fontSize: 10,
                color: _getCallTypeColor(type),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SIM Detection'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActualCallLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_permissionGranted) ...[
            _buildSimInfoCard(),
            _buildSimSelector(),
          ],
          const SizedBox(height: 8),
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage.isNotEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, color: Colors.red),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _checkPermissions,
                        child: const Text('Check Permissions'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_filteredCallLogs.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No call records found'),
                ),
              )
            else
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          const Text(
                            '📋 Call History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          Text(
                            '${_filteredCallLogs.length} calls',
                            style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _filteredCallLogs.length,
                        itemBuilder: (context, index) {
                          return _buildCallLogItem(_filteredCallLogs[index]);
                        },
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}