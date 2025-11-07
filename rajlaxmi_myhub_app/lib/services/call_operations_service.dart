import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class CallOperationsService {
  Future<void> makeCall(String number) async {
    if (number.isEmpty) {
      throw Exception('Phone number is empty');
    }

    try {
      await FlutterPhoneDirectCaller.callNumber(number);
    } catch (e) {
      throw Exception('Error making call: $e');
    }
  }

  Future<void> makeCallWithSpecificSim(String number, String simSlot) async {
    // Platform-specific SIM selection would be implemented here
    await makeCall(number);
  }
}