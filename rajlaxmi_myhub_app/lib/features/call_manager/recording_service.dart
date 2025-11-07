import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

class RecordingService {
  final AudioRecorder _audioRecorder = AudioRecorder();

  // Recording state
  bool _isRecording = false;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime;
  String? _currentPhoneNumber;
  bool? _wasIncomingCall;

  // Getters
  bool get isRecording => _isRecording;
  String? get currentRecordingPath => _currentRecordingPath;
  DateTime? get recordingStartTime => _recordingStartTime;

  // ================================
  // PERMISSION MANAGEMENT
  // ================================
  Future<bool> checkMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      return status.isGranted;
    } catch (e) {
      print("❌ Error checking microphone permission: $e");
      return false;
    }
  }

  Future<bool> initializeRecorder() async {
    try {
      final hasPermission = await checkMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Microphone permission denied');
      }
      print("✅ MP3 Recorder initialized successfully");
      return true;
    } catch (e) {
      print("❌ Error initializing MP3 recorder: $e");
      return false;
    }
  }

  // ================================
  // RECORDING MANAGEMENT
  // ================================
  Future<bool> startAutomaticRecording(String phoneNumber, bool isIncoming) async {
    try {
      print("🎯 STARTING AUTOMATIC MP3 RECORDING FOR: $phoneNumber");

      if (_isRecording) {
        print("🔄 MP3 Recording already in progress, ignoring start request");
        return false;
      }

      if (!await _audioRecorder.hasPermission()) {
        print("❌ Microphone permission denied for MP3 recording");
        return false;
      }

      final recordingPath = await _getMP3RecordingPath(phoneNumber, isIncoming);
      _currentRecordingPath = recordingPath;
      _currentPhoneNumber = phoneNumber;
      _wasIncomingCall = isIncoming;

      print("🎯 Starting MP3 recorder with path: $recordingPath");

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: recordingPath,
      );

      _recordingStartTime = DateTime.now();
      _isRecording = true;

      print("✅ AUTOMATIC MP3 RECORDING STARTED SUCCESSFULLY");
      return true;

    } catch (e) {
      print("❌ CRITICAL ERROR starting automatic MP3 recording: $e");
      return false;
    }
  }

  Future<RecordingResult> stopAutomaticRecording() async {
    if (!_isRecording) {
      print("ℹ️ No automatic MP3 recording in progress to stop");
      return RecordingResult(
          success: false,
          filePath: null,
          duration: 0,
          error: 'No recording in progress'
      );
    }

    try {
      final String? recordingPath = _currentRecordingPath;

      print("⏹️ Stopping automatic MP3 recording...");
      final path = await _audioRecorder.stop();

      _isRecording = false;
      final duration = _calculateRecordingDuration();

      print("⏹️ Automatic MP3 recording stopped successfully");

      if (path != null && File(path).existsSync()) {
        final verification = await _verifyRecordingFile(path);
        return RecordingResult(
            success: true,
            filePath: path,
            duration: duration,
            fileSize: verification.fileSize,
            isValid: verification.isValid
        );
      } else {
        return RecordingResult(
            success: false,
            filePath: null,
            duration: duration,
            error: 'Recording file not found'
        );
      }

    } catch (e) {
      print("❌ Error stopping automatic MP3 recording: $e");
      _isRecording = false;
      return RecordingResult(
          success: false,
          filePath: null,
          duration: 0,
          error: e.toString()
      );
    }
  }

  // ================================
  // FILE MANAGEMENT
  // ================================
  Future<String> _getMP3RecordingPath(String phoneNumber, bool isIncoming) async {
    try {
      Directory directory;
      try {
        directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      } catch (e) {
        directory = await getApplicationDocumentsDirectory();
      }

      final formattedDate = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final safePhoneNumber = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
      final callType = isIncoming ? 'incoming' : 'outgoing';

      final fileName = 'call_${callType}_${safePhoneNumber}_$formattedDate.mp3';
      final recordingsDir = Directory('${directory.path}/CallRecordings');

      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      final fullPath = '${recordingsDir.path}/$fileName';
      print("🎯 Final MP3 path: $fullPath");

      return fullPath;

    } catch (e) {
      print("❌ Error generating MP3 path: $e");
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return '${directory.path}/call_$timestamp.mp3';
    }
  }

  Future<FileVerification> _verifyRecordingFile(String filePath) async {
    try {
      final recordingFile = File(filePath);
      bool fileExists = await recordingFile.exists();

      if (fileExists) {
        final fileSize = await recordingFile.length();
        final isMP3 = filePath.toLowerCase().endsWith('.mp3');
        final recordingDuration = _calculateRecordingDuration();

        print("✅ AUTOMATIC MP3 RECORDING VERIFIED:");
        print("📁 File path: $filePath");
        print("🎵 Format: ${isMP3 ? 'MP3' : 'AAC'}");
        print("💾 File size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB");
        print("⏱️ Recording duration: $recordingDuration seconds");
        print("📞 Call type: ${_wasIncomingCall == true ? 'Incoming' : 'Outgoing'}");

        return FileVerification(
            isValid: true,
            fileSize: fileSize,
            duration: recordingDuration,
            isMP3: isMP3,
            filePath: filePath
        );
      } else {
        print("❌ MP3 RECORDING FILE NOT FOUND: $filePath");
        return FileVerification(
            isValid: false,
            fileSize: 0,
            duration: 0,
            isMP3: false,
            filePath: filePath,
            error: 'File not found'
        );
      }

    } catch (e) {
      print("❌ Error verifying MP3 recording: $e");
      return FileVerification(
          isValid: false,
          fileSize: 0,
          duration: 0,
          isMP3: false,
          filePath: filePath,
          error: e.toString()
      );
    }
  }

  int _calculateRecordingDuration() {
    if (_recordingStartTime == null) return 0;
    return DateTime.now().difference(_recordingStartTime!).inSeconds;
  }

  // ================================
  // MANUAL RECORDING MANAGEMENT
  // ================================
  Future<List<RecordingInfo>> getRecordedCallsWithInfo() async {
    try {
      final Directory directory = await getExternalStorageDirectory() ?? await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${directory.path}/CallRecordings');

      if (await recordingsDir.exists()) {
        final files = recordingsDir.listSync();
        final List<RecordingInfo> recordings = [];

        for (var file in files) {
          if (file is File && file.path.toLowerCase().endsWith('.mp3')) {
            try {
              final stat = await file.stat();
              final size = await file.length();
              final fileName = file.path.split('/').last;

              String displayName = 'Unknown Call';
              String callDate = 'Unknown Date';
              String callType = 'Unknown';
              String phoneNumber = 'Unknown';

              try {
                final parts = fileName.split('_');
                if (parts.length >= 4) {
                  final typePart = parts[1];
                  final phonePart = parts[2];
                  final datePart = parts[3].split('.')[0];

                  callType = typePart;
                  phoneNumber = phonePart.replaceAll('_', '');
                  displayName = '${typePart.toUpperCase()} - +$phoneNumber';
                  callDate = '${datePart.substring(6, 8)}/${datePart.substring(4, 6)}/${datePart.substring(0, 4)} ${datePart.substring(9, 11)}:${datePart.substring(11, 13)}';
                }
              } catch (e) {
                displayName = fileName;
              }

              recordings.add(RecordingInfo(
                file: file,
                path: file.path,
                fileName: fileName,
                displayName: displayName,
                callDate: callDate,
                callType: callType,
                phoneNumber: phoneNumber,
                format: 'MP3',
                size: size,
                sizeMB: (size / 1024 / 1024).toStringAsFixed(2),
                modified: stat.modified,
              ));
            } catch (e) {
              print("Error reading MP3 file info: ${file.path}");
            }
          }
        }

        recordings.sort((a, b) => b.modified.compareTo(a.modified));
        return recordings;
      }
      return [];
    } catch (e) {
      print("❌ Error listing MP3 recordings: $e");
      return [];
    }
  }

  // ================================
  // CLEANUP
  // ================================
  Future<void> dispose() async {
    if (_isRecording) {
      await stopAutomaticRecording();
    }
    _audioRecorder.dispose();
    _resetRecordingState();
  }

  void _resetRecordingState() {
    _isRecording = false;
    _currentRecordingPath = null;
    _recordingStartTime = null;
    _currentPhoneNumber = null;
    _wasIncomingCall = null;
  }

  // ================================
  // UTILITY METHODS
  // ================================
  String getRecordingStatus() {
    if (!_isRecording) return "No active recording";

    final duration = _calculateRecordingDuration();
    final callType = _wasIncomingCall == true ? "Incoming" : "Outgoing";

    return "Recording $callType call with $_currentPhoneNumber - Duration: ${duration}s";
  }

  bool hasActiveRecording() {
    return _isRecording;
  }
}

// ================================
// DATA MODELS
// ================================
class RecordingResult {
  final bool success;
  final String? filePath;
  final int duration;
  final int? fileSize;
  final bool isValid;
  final String? error;

  RecordingResult({
    required this.success,
    required this.filePath,
    required this.duration,
    this.fileSize,
    this.isValid = false,
    this.error,
  });
}

class FileVerification {
  final bool isValid;
  final int fileSize;
  final int duration;
  final bool isMP3;
  final String filePath;
  final String? error;

  FileVerification({
    required this.isValid,
    required this.fileSize,
    required this.duration,
    required this.isMP3,
    required this.filePath,
    this.error,
  });
}

class RecordingInfo {
  final File file;
  final String path;
  final String fileName;
  final String displayName;
  final String callDate;
  final String callType;
  final String phoneNumber;
  final String format;
  final int size;
  final String sizeMB;
  final DateTime modified;

  RecordingInfo({
    required this.file,
    required this.path,
    required this.fileName,
    required this.displayName,
    required this.callDate,
    required this.callType,
    required this.phoneNumber,
    required this.format,
    required this.size,
    required this.sizeMB,
    required this.modified,
  });
}