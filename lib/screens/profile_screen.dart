import 'package:carbonsense/theme/app_theme.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _bioController;

  @override
  void initState() {
    super.initState();
    // Swapped the placeholder name to yours to make it official!
    _nameController = TextEditingController(text: 'Ivan Kurtz');
    _bioController = TextEditingController(
        text:
            'Passionate about sustainability and finding new ways to reduce my carbon footprint.');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start, // Snaps to top
              crossAxisAlignment: CrossAxisAlignment.stretch, // Expands full width
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                      },
                      child: Text(
                        _isEditing ? 'Save' : 'Edit',
                        style: const TextStyle(
                          fontSize: 16, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Aligned center so the avatar doesn't stretch across the iPad
                const Align(
                  alignment: Alignment.center,
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: AppTheme.primaryColor,
                    child: Icon(Icons.person, size: 80, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  enabled: _isEditing,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _bioController,
                  enabled: _isEditing,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Your bio here...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}