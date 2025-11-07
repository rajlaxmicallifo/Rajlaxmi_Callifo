import 'package:flutter/services.dart';

class SimDetectionService {
  static const MethodChannel _channel = MethodChannel('call_log_service');

  /// Check if call log permissions are granted
  static Future<bool> hasPermissions() async {
    try {
      final bool result = await _channel.invokeMethod('hasPermissions');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check permissions: '${e.message}'");
      return false;
    }
  }

  /// Get call logs with SIM information
  static Future<List<dynamic>> getCallLogs() async {
    try {
      final List<dynamic> result = await _channel.invokeMethod('getCallLogs');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get call logs: '${e.message}'");
      return [];
    }
  }

  /// Get SIM card information
  static Future<Map<dynamic, dynamic>> getSimInfo() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getSimInfo');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get SIM info: '${e.message}'");
      return {
        'availableSims': 0,
        'activeSims': 0,
        'sim1State': 'unknown',
        'sim2State': 'unknown',
        'sim1Number': '',
        'sim2Number': '',
        'sim1Operator': '',
        'sim2Operator': '',
        'sim1Country': '',
        'sim2Country': ''
      };
    }
  }

  /// Make call with specific SIM
  static Future<bool> makeCallWithSim(String number, String simSlot) async {
    try {
      final bool result = await _channel.invokeMethod('makeCallWithSim', {
        'number': number,
        'simSlot': simSlot,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to make call with SIM: '${e.message}'");
      return false;
    }
  }

  /// Change default SIM card
  static Future<bool> changeDefaultSim(String simSlot) async {
    try {
      final bool result = await _channel.invokeMethod('changeDefaultSim', {
        'simSlot': simSlot,
      });
      return result;
    } on PlatformException catch (e) {
      print("Failed to change default SIM: '${e.message}'");
      return false;
    }
  }

  /// Get current SIM selection
  static Future<String> getCurrentSimSelection() async {
    try {
      final String result = await _channel.invokeMethod('getCurrentSimSelection');
      return result;
    } on PlatformException catch (e) {
      print("Failed to get current SIM selection: '${e.message}'");
      return 'sim1';
    }
  }

  /// Check if SIM change is supported
  static Future<bool> isSimChangeSupported() async {
    try {
      final bool result = await _channel.invokeMethod('isSimChangeSupported');
      return result;
    } on PlatformException catch (e) {
      print("Failed to check SIM change support: '${e.message}'");
      return false;
    }
  }

  /// Refresh SIM status
  static Future<Map<dynamic, dynamic>> refreshSimStatus() async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('refreshSimStatus');
      return result;
    } on PlatformException catch (e) {
      print("Failed to refresh SIM status: '${e.message}'");
      return {};
    }
  }
}