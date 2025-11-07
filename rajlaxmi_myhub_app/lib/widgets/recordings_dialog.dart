import 'package:flutter/material.dart';
import '../features/call_manager/recording_service.dart';

class RecordingsDialog extends StatelessWidget {
  final List<RecordingInfo> recordings;
  final VoidCallback onUploadPressed;

  const RecordingsDialog({
    super.key,
    required this.recordings,
    required this.onUploadPressed,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('MP3 Call Recordings'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: recordings.length,
          itemBuilder: (context, index) {
            final recording = recordings[index];
            return ListTile(
              leading: const Icon(Icons.audio_file, color: Colors.blue),
              title: Text(recording.displayName),
              subtitle: Text('${recording.callDate} • ${recording.sizeMB} MB'),
              trailing: IconButton(
                icon: const Icon(Icons.upload, color: Colors.green),
                onPressed: onUploadPressed,
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}