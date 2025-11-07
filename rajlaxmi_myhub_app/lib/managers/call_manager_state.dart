import 'package:call_log/call_log.dart';
import 'package:phone_state/phone_state.dart';

class CallManagerState {
  // Call State Management
  String phoneNumber = '';
  bool incomingCall = false;
  bool outgoingCall = false;
  bool isInCall = false;
  bool isCallAnswered = false;
  bool wasIncomingCall = false;
  bool isOutgoingDialing = false;
  String? currentCallNumber;
  DateTime? callStartTime;
  PhoneStateStatus? lastCallStatus;

  // SIM Detection & Change State
  int availableSims = 1;
  String selectedSimForCall = 'sim1';
  String selectedSimForFilter = 'all';
  Map<dynamic, dynamic> simInfo = {};
  bool simDetectionEnabled = true;
  String simStatus = 'Checking...';
  bool isChangingSim = false;
  String simChangeStatus = '';

  // UI & Data State
  List<CallLogEntry> callHistory = [];
  List<CallLogEntry> filteredCalls = [];
  String selectedFilter = 'All';
  bool isFetching = false;
  final Set<String> uploadedCallIds = {};
  final Set<String> uploadInProgress = {};

  // Call SIM Mapping
  final Map<String, String> callSimMapping = {};

  static const List<String> filters = ['All', 'Incoming', 'Outgoing', 'Missed'];
}