  import 'dart:convert';
  import 'dart:io';
  import 'package:http/http.dart' as http;

  class CallService {
    final String baseUrl = 'http://192.168.1.17:8000/api/calls/';
    String? authToken;

    void setToken(String token) {
      authToken = token;
    }

    /// Upload a call log with MP3 recording file
    Future<String> uploadCallWithRecording({
      required Map<String, dynamic> callData,
      required File recordingFile,
    }) async {
      if (authToken == null) return "Error: Auth token is null";

      try {
        // ✅ Allow multiple audio formats
        final allowedExtensions = ['.mp3', '.m4a', '.aac', '.wav', '.ogg'];
        final fileExtension = recordingFile.path.toLowerCase().split('.').last;

        if (!allowedExtensions.any((ext) => recordingFile.path.toLowerCase().endsWith(ext))) {
          return "Error: Only audio files are allowed (MP3, M4A, AAC, WAV, OGG)";
        }

        // ✅ Check file size (max 50MB for audio files)
        final fileStat = await recordingFile.stat();
        if (fileStat.size > 50 * 1024 * 1024) {
          return "Error: Audio file too large (max 50MB)";
        }

        var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
        request.headers['Authorization'] = 'Token $authToken';

        // Add call data fields
        callData.forEach((key, value) {
          request.fields[key] = value.toString();
        });

        // Add recording file with proper content type
        request.files.add(await http.MultipartFile.fromPath(
          'recording',
          recordingFile.path,
        ));

        var response = await request.send();
        var responseBody = await response.stream.bytesToString();

        print('📤 Upload Response: ${response.statusCode}');
        print('📤 Upload Body: $responseBody');

        if (response.statusCode == 201) {
          return 'Call with recording uploaded successfully';
        }
        return 'Failed: ${response.statusCode} $responseBody';
      } catch (e) {
        return 'Error uploading call with recording: $e';
      }
    }



    /// Upload a call log with MP3 validation
    Future<String> uploadCall({
      String? phoneNumber,
      String? callType,
      int? duration,
      Map<String, dynamic>? logData,
      File? recording,
    }) async {
      if (authToken == null) return "User not logged in";

      try {
        // ✅ Validate MP3 if recording provided
        if (recording != null) {
          if (!recording.path.toLowerCase().endsWith('.mp3')) {
            return "Error: Only MP3 files are allowed";
          }

          final fileStat = await recording.stat();
          if (fileStat.size > 50 * 1024 * 1024) {
            return "Error: MP3 file too large (max 50MB)";
          }
        }

        // Build payload
        Map<String, dynamic> payload;

        if (logData != null) {
          payload = Map<String, dynamic>.from(logData);
        } else {
          payload = {
            'caller_number': phoneNumber ?? '',
            'call_type': callType ?? 'incoming',
            'duration': duration ?? 0,
            'call_id': DateTime.now().millisecondsSinceEpoch.toString(),
            'start_time': DateTime.now().toIso8601String(),
            'staff_id': 1,
          };
        }

        http.Response response;

        if (recording != null) {
          var request = http.MultipartRequest('POST', Uri.parse(baseUrl));
          request.headers['Authorization'] = 'Token $authToken';

          payload.forEach((key, value) {
            request.fields[key] = value.toString();
          });

          request.files.add(await http.MultipartFile.fromPath('recording', recording.path));
          var streamed = await request.send().timeout(const Duration(seconds: 15));
          response = await http.Response.fromStream(streamed);
        } else {
          response = await http.post(
            Uri.parse(baseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Token $authToken',
            },
            body: jsonEncode(payload),
          ).timeout(const Duration(seconds: 10));
        }

        print('📤 Upload Response Status: ${response.statusCode}');
        print('📤 Upload Response Body: ${response.body}');

        if (response.statusCode == 201 || response.statusCode == 200) {
          return 'Call uploaded successfully';
        }
        return 'Failed: ${response.statusCode} ${response.body}';
      } catch (e) {
        return 'Error uploading call: $e';
      }
    }

    // ... rest of your existing methods remain the same ...
    /// New method specifically for structured call data
    Future<String> uploadCallWithData({
      required Map<String, dynamic> callData,
      File? recording,
    }) async {
      return uploadCall(logData: callData, recording: recording);
    }

    /// Finish a call in Bitrix24 (called when call ends)
    Future<String> finishCall({
      required String callId,
      required int duration,
      required String status,
      String? notes,
    }) async {
      if (authToken == null) return "Error: Auth token is null";

      try {
        final response = await http.post(
          Uri.parse('${baseUrl}finish/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $authToken',
          },
          body: jsonEncode({
            'call_id': callId,
            'duration': duration,
            'status': status,
            'notes': notes ?? '',
          }),
        ).timeout(const Duration(seconds: 10));

        print('🏁 Finish Call Response: ${response.statusCode}');
        print('🏁 Finish Call Body: ${response.body}');

        if (response.statusCode == 200) {
          return 'Call finished successfully';
        } else {
          return 'Failed to finish call: ${response.body}';
        }
      } catch (e) {
        return 'Error finishing call: $e';
      }
    }

    /// Get call statistics from Bitrix24
    Future<Map<String, dynamic>> getBitrixStats({
      required int userId,
      String? dateFrom,
      String? dateTo,
    }) async {
      if (authToken == null) return {'error': 'Not authenticated'};

      try {
        final queryParams = {
          'user_id': userId.toString(),
          if (dateFrom != null) 'date_from': dateFrom,
          if (dateTo != null) 'date_to': dateTo,
        };

        final uri = Uri.parse('${baseUrl}stats/').replace(queryParameters: queryParams);

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Token $authToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        print('📊 Bitrix Stats Response: ${response.statusCode}');
        print('📊 Bitrix Stats Body: ${response.body}');

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          return {'error': 'Failed to get stats: ${response.statusCode}'};
        }
      } catch (e) {
        return {'error': 'Error getting stats: $e'};
      }
    }

    /// Fetch local call statistics from Django backend
    Future<Map<String, dynamic>> fetchCallStats({
      int? staffId,
      String? dateFrom,
      String? dateTo,
    }) async {
      if (authToken == null) return {'error': 'Not authenticated'};

      try {
        final queryParams = <String, String>{};
        if (staffId != null) queryParams['staff_id'] = staffId.toString();
        if (dateFrom != null) queryParams['date_from'] = dateFrom;
        if (dateTo != null) queryParams['date_to'] = dateTo;

        final uri = Uri.parse('${baseUrl}stats/').replace(queryParameters: queryParams);

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Token $authToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else {
          print('❌ Failed to fetch stats: ${response.statusCode}');
          return {'error': 'Failed to fetch stats'};
        }
      } catch (e) {
        print('❌ Error fetching stats: $e');
        return {'error': 'Network error'};
      }
    }

    /// Get call history for a specific staff member
    Future<List<Map<String, dynamic>>> getCallHistory({
      int? staffId,
      int limit = 50,
    }) async {
      if (authToken == null) return [];

      try {
        final queryParams = <String, String>{
          'limit': limit.toString(),
        };
        if (staffId != null) queryParams['staff_id'] = staffId.toString();

        final uri = Uri.parse('${baseUrl}history/').replace(queryParameters: queryParams);

        final response = await http.get(
          uri,
          headers: {
            'Authorization': 'Token $authToken',
            'Content-Type': 'application/json',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          return data.cast<Map<String, dynamic>>();
        } else {
          print('❌ Failed to fetch call history: ${response.statusCode}');
          return [];
        }
      } catch (e) {
        print('❌ Error fetching call history: $e');
        return [];
      }
    }

    /// Create a properly formatted call data map for upload
    Map<String, dynamic> createCallData({
      required String phoneNumber,
      required String callType,
      required int duration,
      String? callId,
      String? callerName,
      String? startTime,
      String? endTime,
      int staffId = 1,
      String? notes,
    }) {
      return {
        'call_id': callId ?? DateTime.now().millisecondsSinceEpoch.toString(),
        'caller_number': phoneNumber,
        'phone_number': phoneNumber,
        'call_type': callType,
        'start_time': startTime ?? DateTime.now().toIso8601String(),
        'end_time': endTime,
        'duration': duration,
        'staff_id': staffId,
        'user': staffId,
        if (callerName != null) 'caller_name': callerName,
        if (notes != null) 'notes': notes,
      };
    }

    /// Register an incoming call immediately for real-time Bitrix24 popup
    Future<String> registerIncomingCallImmediately({
      required String phoneNumber,
      required int staffId,
      String? callerName,
    }) async {
      if (authToken == null) return "Error: Auth token is null";

      try {
        final response = await http.post(
          Uri.parse('${baseUrl}register-immediate/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Token $authToken',
          },
          body: jsonEncode({
            'phone_number': phoneNumber,
            'staff_id': staffId,
            'caller_name': callerName ?? '',
          }),
        ).timeout(const Duration(seconds: 5));

        print("⚡ Immediate registration response: ${response.statusCode}");
        print("⚡ Response body: ${response.body}");

        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          return result['bitrix_call_id'] ?? 'registered';
        } else {
          return 'Failed to register immediate call';
        }
      } catch (e) {
        return 'Error: $e';
      }
    }

    /// Complete workflow: Register call, then finish it
    Future<Map<String, String>> handleCallComplete({
      required String phoneNumber,
      required String callType,
      required int duration,
      required int staffId,
      String? callerName,
      String? notes,
      String? status,
      File? recording,
    }) async {
      // Step 1: Register/Upload the call
      final callId = DateTime.now().millisecondsSinceEpoch.toString();

      final callData = createCallData(
        phoneNumber: phoneNumber,
        callType: callType,
        duration: duration,
        callId: callId,
        callerName: callerName,
        staffId: staffId,
        notes: notes,
        endTime: DateTime.now().toIso8601String(),
      );

      final uploadResult = await uploadCallWithData(callData: callData, recording: recording);

      // Step 2: If upload successful and it's a Bitrix24 integrated call, finish it
      if (uploadResult.contains('successfully')) {
        final finishResult = await finishCall(
          callId: callId,
          duration: duration,
          status: status ?? 'completed',
          notes: notes,
        );

        return {
          'call_id': callId,
          'upload_result': uploadResult,
          'finish_result': finishResult,
        };
      } else {
        return {
          'call_id': callId,
          'upload_result': uploadResult,
          'finish_result': 'Skipped due to upload failure',
        };
      }
    }

    /// Test connection to backend
    Future<bool> testConnection() async {
      try {
        final response = await http.get(
          Uri.parse(baseUrl.replaceAll('/calls/', '/health/')),
          headers: {
            if (authToken != null) 'Authorization': 'Token $authToken',
          },
        ).timeout(const Duration(seconds: 5));

        return response.statusCode == 200;
      } catch (e) {
        print('❌ Connection test failed: $e');
        return false;
      }
    }
  }