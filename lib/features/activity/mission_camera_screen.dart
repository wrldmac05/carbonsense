import 'dart:convert';
import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MissionCameraScreen extends StatefulWidget {
  final String taskDescription;
  final String visionCriteria;
  final String userTaskId;

  const MissionCameraScreen({super.key, required this.taskDescription, required this.visionCriteria, required this.userTaskId});

  @override
  State<MissionCameraScreen> createState() => _MissionCameraScreenState();
}

class _MissionCameraScreenState extends State<MissionCameraScreen> {
  // Cross-platform compatibility (Web, iOS, Android)
  XFile? _photo;
  Uint8List? _imageBytes;
  bool _isProcessing = false;
  final ImagePicker _picker = ImagePicker();

  Future<void> _takePicture() async {
    if (_isProcessing) return;

    try {
      // Limit dimensions to 1024x1024 to curb memory usage and Base64 transfer size
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70, maxWidth: 1024, maxHeight: 1024);

      if (photo != null && mounted) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _photo = photo;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error taking picture: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to open camera. Please check permissions.')));
      }
    }
  }

  Future<void> _submitForVerification() async {
    if (_imageBytes == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User is not authenticated.");

      // Offload Base64 encoding to background isolate on mobile/desktop
      final base64Image = kIsWeb ? base64Encode(_imageBytes!) : await compute(base64Encode, _imageBytes!);

      final response = await Supabase.instance.client.functions.invoke('verify_mission_vision', body: {'image_base64': base64Image, 'vision_criteria': widget.visionCriteria});

      if (!mounted) return;

      if (response.status == 200 && response.data is Map) {
        final Map<String, dynamic> decodedData = Map<String, dynamic>.from(response.data as Map);

        final bool isVerified = decodedData['is_verified'] == true;
        final rawReason = decodedData['reason']?.toString().trim() ?? 'AI could not process the image.';
        final reason = rawReason.length > 300 ? rawReason.substring(0, 300) : rawReason;

        if (isVerified) {
          // Scoped strictly to current user's ID to prevent cross-account task updates
          await Supabase.instance.client
              .from('user_tasks')
              .update({'is_completed': true, 'completed_at': DateTime.now().toUtc().toIso8601String()})
              .eq('user_task_id', widget.userTaskId)
              .eq('user_id', user.id);

          if (!mounted) return;
          _showResultDialog(true, 'Mission Accomplished!', reason);
        } else {
          _showResultDialog(false, 'Verification Failed', reason);
        }
      } else {
        throw Exception("Server responded with code ${response.status}");
      }
    } catch (e) {
      debugPrint('Vision API Error: $e');
      if (!mounted) return;

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('quota') || errorStr.contains('429')) {
        _showResultDialog(false, 'System Busy', 'Our vision system is experiencing high demand. Please try again shortly.');
      } else {
        // Prevent backend/database stack trace leakage to UI
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification service is temporarily unavailable. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showResultDialog(bool success, String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(success ? Icons.check_circle : Icons.error_outline, color: success ? Colors.green : Colors.red),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.white70)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: success ? Colors.green : AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(dialogContext);

              if (success && mounted) {
                Navigator.pop(context);
              }
            },
            child: Text(
              success ? 'Awesome' : 'Try Again',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isProcessing,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(color: Colors.white),
          title: const Text(
            'AI Verification',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Task Instruction Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    const Text(
                      "PROVE YOUR MISSION",
                      style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.taskDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              // Camera Viewfinder / Image Preview (Web and native agnostic)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: double.infinity,
                      color: Colors.grey.shade900,
                      child: _imageBytes != null
                          ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 64, color: Colors.grey.shade700),
                                const SizedBox(height: 16),
                                Text('Tap below to open camera', style: TextStyle(color: Colors.grey.shade500)),
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
                    ? const CircularProgressIndicator(color: AppTheme.primaryColor)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          if (_imageBytes != null)
                            TextButton.icon(
                              onPressed: _takePicture,
                              icon: const Icon(Icons.refresh, color: Colors.white70),
                              label: const Text('Retake', style: TextStyle(color: Colors.white70)),
                            ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _imageBytes == null ? _takePicture : _submitForVerification,
                            icon: Icon(_imageBytes == null ? Icons.camera : Icons.auto_awesome, color: Colors.white),
                            label: Text(
                              _imageBytes == null ? 'Take Photo' : 'Analyze Image',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
