import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:call_log/call_log.dart';
import 'package:intl/intl.dart';
import 'package:rajlaxmi_myhub_app/shared_prefs_service.dart';
import 'Call_Data/call_service.dart';
import 'call_manager_page.dart';

class HomeScreen extends StatefulWidget {
  final String authToken;
  final String name;
  final String email;

  const HomeScreen({
    super.key,
    required this.authToken,
    required this.name,
    required this.email,
  });

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CallService callService = CallService();
  final ImagePicker _picker = ImagePicker();

  int totalCalls = 0;
  int incomingCalls = 0;
  int outgoingCalls = 0;
  int missedCalls = 0;
  File? _profileImage;

  // Call history state
  List<CallLogEntry> callHistory = [];
  bool isLoadingHistory = false;

  // Call analysis counts from device call log
  int allCallsCount = 0;
  int incomingCount = 0;
  int outgoingCount = 0;
  int missedCount = 0;

  @override
  void initState() {
    super.initState();
    callService.setToken(widget.authToken);
    fetchCallStats();
    _loadCallHistory();
    _analyzeCallLogs();
  }

  Future<void> fetchCallStats() async {
    final stats = await callService.fetchCallStats();
    setState(() {
      totalCalls = stats['total_calls'] ?? 0;
      incomingCalls = stats['incoming_calls'] ?? 0;
      outgoingCalls = stats['outgoing_calls'] ?? 0;
      missedCalls = stats['missed_calls'] ?? 0;
    });
  }

  Future<void> _loadCallHistory() async {
    setState(() {
      isLoadingHistory = true;
    });

    try {
      final Iterable<CallLogEntry> entries = await CallLog.get();
      setState(() {
        callHistory = entries.take(5).toList(); // Show only last 5 calls
        isLoadingHistory = false;
      });
    } catch (e) {
      print('Error loading call history: $e');
      setState(() {
        isLoadingHistory = false;
      });
    }
  }

  Future<void> _analyzeCallLogs() async {
    try {
      final Iterable<CallLogEntry> entries = await CallLog.get();

      // Calculate counts based on call types
      final allCalls = entries.toList();
      final incoming = allCalls.where((c) => c.callType == CallType.incoming).toList();
      final outgoing = allCalls.where((c) => c.callType == CallType.outgoing).toList();
      final missed = allCalls.where((c) => c.callType == CallType.missed).toList();

      setState(() {
        allCallsCount = allCalls.length;
        incomingCount = incoming.length;
        outgoingCount = outgoing.length;
        missedCount = missed.length;
      });
    } catch (e) {
      print('Error analyzing call logs: $e');
    }
  }

  Future<void> pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  void navigateToCallManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CallManagerPage(authToken: widget.authToken),
      ),
    );
  }

  Future<void> _logout() async {
    await SharedPrefsService.clearUserData();
    Navigator.pushReplacementNamed(context, '/login');
  }

  // Call Analysis Card Widget
  Widget _buildCallAnalysisCard(String title, int count, Color color, IconData icon, String subtitle) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 110,
        maxHeight: 130,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
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

  // Call History Item Widget
  Widget _buildCallHistoryItem(CallLogEntry entry) {
    final (iconColor, iconData) = _getCallTypeInfo(entry);
    final time = _formatTime(entry.timestamp);

    return Card(
      elevation: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.2),
          child: Icon(iconData, color: iconColor, size: 20),
        ),
        title: Text(
          entry.name ?? entry.number ?? 'Unknown',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${entry.number ?? ''} • ${entry.duration ?? 0}s • $time',
              style: const TextStyle(fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: iconColor, width: 0.5),
              ),
              child: Text(
                _getCallTypeLabel(entry.callType),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: iconColor,
                ),
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey[600],
        ),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Call ${entry.number ?? ''}')),
          );
        },
      ),
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

  String _getCallTypeLabel(CallType? callType) {
    return switch (callType) {
      CallType.missed => 'MISSED',
      CallType.incoming => 'INCOMING',
      CallType.outgoing => 'OUTGOING',
      _ => 'UNKNOWN',
    };
  }

  String _formatTime(int? timestamp) {
    if (timestamp == null) return '';
    final DateTime ts = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateFormat('MMM dd, HH:mm').format(ts);
  }

  // Fixed Stat Card with proper constraints
  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 120,
        maxHeight: 140,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Feature Card
  Widget _buildFeatureCard(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: color, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Callifo',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF4ECDC4)),
            onPressed: () {
              fetchCallStats();
              _loadCallHistory();
              _analyzeCallLogs();
            },
            tooltip: 'Refresh All',
          ),
        ],
      ),
      drawer: _buildProfessionalDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.green.shade50],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${widget.name.split(' ').first}!',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage your calls and communications',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4ECDC4).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.waving_hand, color: Color(0xFF4ECDC4), size: 20),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Call Analysis Section (from Device Call Log)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Call Analysis',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'From device call log',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Call Analysis Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.2,
              children: [
                _buildCallAnalysisCard(
                  'All Calls',
                  allCallsCount,
                  const Color(0xFF4ECDC4),
                  Icons.call,
                  'Total calls',
                ),
                _buildCallAnalysisCard(
                  'Incoming',
                  incomingCount,
                  Colors.green,
                  Icons.call_received,
                  'Received calls',
                ),
                _buildCallAnalysisCard(
                  'Outgoing',
                  outgoingCount,
                  Colors.blue,
                  Icons.call_made,
                  'Dialed calls',
                ),
                _buildCallAnalysisCard(
                  'Missed',
                  missedCount,
                  Colors.orange,
                  Icons.call_missed,
                  'Missed calls',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Calls Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Calls',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                TextButton(
                  onPressed: navigateToCallManager,
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: const Color(0xFF4ECDC4),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Call History List - Show only 5 items
            if (isLoadingHistory)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4ECDC4)),
                  ),
                ),
              )
            else if (callHistory.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.phone_disabled,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No recent calls',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Make some calls to see history here',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              )
            else
              Column(
                children: callHistory.map((entry) => _buildCallHistoryItem(entry)).toList(),
              ),

            const SizedBox(height: 24),

            // Features Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Calling File Feature - Prominently Displayed
            _buildFeatureCard(
              'Call Manager',
              'Manage calls, recordings & SIM selection',
              Icons.phone_in_talk,
              const Color(0xFF4ECDC4),
              navigateToCallManager,
            ),

            const SizedBox(height: 8),

            // Additional Features
            _buildFeatureCard(
              'Call Analytics',
              'View detailed call reports & insights',
              Icons.analytics,
              Colors.purple,
                  () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Analytics feature coming soon!')),
                );
              },
            ),

            const SizedBox(height: 8),

            _buildFeatureCard(
              'Settings',
              'Configure app preferences',
              Icons.settings,
              Colors.blue,
                  () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings feature coming soon!')),
                );
              },
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),

      // Floating Action Button for Quick Call Access
      floatingActionButton: FloatingActionButton(
        onPressed: navigateToCallManager,
        backgroundColor: const Color(0xFF4ECDC4),
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.arrow_circle_right, size: 24),
      ),
    );
  }

  Widget _buildProfessionalDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      elevation: 16,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Header with gradient background
            Container(
              height: 180,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade600, Colors.blue.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Icon(
                      Icons.phone_in_talk,
                      size: 60,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 8),
                        // Profile Image with edit button
                        Stack(
                          children: [
                            Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _profileImage != null
                                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                                    : Container(
                                  color: Colors.white.withOpacity(0.2),
                                  child: Icon(
                                    Icons.person,
                                    size: 35,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: pickProfileImage,
                                child: Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4ECDC4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            widget.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Quick Stats - More compact
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),

                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items - Using Expanded with constraints
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Navigation Section
                      _buildDrawerSectionHeader('Navigation'),
                      _buildDrawerMenuItem(
                        title: 'Call Manager',
                        subtitle: 'Manage calls & recordings',
                        icon: Icons.arrow_circle_right,
                        color: const Color(0xFF4ECDC4),
                        onTap: navigateToCallManager,
                      ),
                      _buildDrawerMenuItem(
                        title: 'Call Analytics',
                        subtitle: 'Detailed reports & insights',
                        icon: Icons.analytics,
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Analytics feature coming soon!')),
                          );
                        },
                      ),
                      _buildDrawerMenuItem(
                        title: 'Settings',
                        subtitle: 'App preferences & configuration',
                        icon: Icons.settings,
                        color: Colors.blue,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Settings feature coming soon!')),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // Support Section
                      _buildDrawerSectionHeader('Support'),
                      _buildDrawerMenuItem(
                        title: 'Help & Support',
                        subtitle: 'Get help and documentation',
                        icon: Icons.help_outline,
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Help & Support feature coming soon!')),
                          );
                        },
                      ),
                      _buildDrawerMenuItem(
                        title: 'About App',
                        subtitle: 'Version info and details',
                        icon: Icons.info_outline,
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('About App feature coming soon!')),
                          );
                        },
                      ),

                      const SizedBox(height: 16),

                      // Logout Section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                          child: _buildDrawerMenuItem(
                            title: 'Logout',
                            subtitle: 'Sign out from your account',
                            icon: Icons.logout,
                            color: Colors.red,
                            onTap: _logout,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        dense: true,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.15), color.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.arrow_forward_ios,
            size: 10,
            color: color,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDrawerStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}