import 'dart:convert';
import 'dart:io';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionCameraScreen extends StatefulWidget {
  final String taskDescription;
  final String visionCriteria; // 👈 1. ADD THIS
  final String userTaskId;

  const MissionCameraScreen({
    Key? key,
    required this.taskDescription,
    required this.visionCriteria, // 👈 2. ADD THIS
    required this.userTaskId,
  }) : super(key: key);

  @override
  State<MissionCameraScreen> createState() => _MissionCameraScreenState();
}

class _MissionCameraScreenState extends State<MissionCameraScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    try {
      // Compressing quality to 70 prevents massive base64 string payloads
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );

      if (photo != null) {
        setState(() {
          _imageFile = File(photo.path);
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
    }
  }

  Future<void> _submitForVerification() async {
    if (_imageFile == null) return;

    setState(() => _isProcessing = true);

    try {
      // 1. Convert image to Base64
      final bytes = await _imageFile!.readAsBytes();
      final base64Image = base64Encode(bytes);

      // 2. Send to your Supabase Edge Function for Gemini processing
      final response = await Supabase.instance.client.functions.invoke(
        'verify_mission_vision',
        body: {
          'image_base64': base64Image,
          'vision_criteria': widget.visionCriteria,
        },
      );

      // 3. Robust JSON Decoding
      // The edge function now returns JSON directly, so response.data is already a Map!
      final Map<String, dynamic> decodedData =
          response.data as Map<String, dynamic>;

      final bool isVerified = decodedData['is_verified'] ?? false;
      final String reason =
          decodedData['reason'] ?? 'AI could not process the image.';

      if (!context.mounted) return;

      if (isVerified) {
        // 4. Update Database on Success
        await Supabase.instance.client
            .from('user_tasks')
            .update({
              'is_completed': true,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('user_task_id', widget.userTaskId);

        if (!context.mounted) return;
        _showResultDialog(true, 'Mission Accomplished!', reason);
      } else {
        // 5. Handle AI Rejection
        _showResultDialog(false, 'Verification Failed', reason);
      }
    } catch (e) {
      debugPrint('Vision API Error: $e');
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error contacting AI server: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(bool success, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error_outline,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? Colors.green : AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(context); // Close dialog
              if (success) {
                Navigator.pop(context); // Go back to dashboard if successful
              }
            },
            child: Text(
              success ? 'Awesome' : 'Try Again',
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'AI Verification',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Task Instruction Banner
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text(
                    "PROVE YOUR MISSION",
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.taskDescription,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Camera Viewfinder / Image Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    color: Colors.grey.shade900,
                    child: _imageFile != null
                        ? Image.file(_imageFile!, fit: BoxFit.cover)
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt,
                                size: 64,
                                color: Colors.grey.shade700,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Tap below to open camera',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isProcessing
                  ? const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (_imageFile != null)
                          TextButton.icon(
                            onPressed: _takePicture,
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white70,
                            ),
                            label: const Text(
                              'Retake',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _imageFile == null
                              ? _takePicture
                              : _submitForVerification,
                          icon: Icon(
                            _imageFile == null
                                ? Icons.camera
                                : Icons.auto_awesome,
                            color: Colors.white,
                          ),
                          label: Text(
                            _imageFile == null ? 'Take Photo' : 'Analyze Image',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
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
}
