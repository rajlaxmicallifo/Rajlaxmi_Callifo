import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestCallPermissions() async {
    final results = await [
      Permission.phone,
      Permission.contacts,
      Permission.storage,
      Permission.microphone,
      Permission.manageExternalStorage,
    ].request();

    return results[Permission.phone]?.isGranted ?? false;
  }
}