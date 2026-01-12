// lib/offline_mode_page.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OfflineModePage extends StatefulWidget {
  const OfflineModePage({super.key});

  @override
  State<OfflineModePage> createState() => _OfflineModePageState();
}

class _OfflineModePageState extends State<OfflineModePage> {
  bool _offlineModeEnabled = false;
  bool _modelsDownloaded = false;
  bool _isDownloading = false;
  final Color primaryColor = const Color(0xFF4A90E2);

  @override
  void initState() {
    super.initState();
    _loadOfflinePreference();
    _checkModelsDownloadedPreference();
  }

  Future<void> _loadOfflinePreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _offlineModeEnabled = prefs.getBool('offlineModeEnabled') ?? false;
    });
  }

  Future<void> _saveOfflinePreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offlineModeEnabled', enabled);
    if (!mounted) return;
    setState(() {
      _offlineModeEnabled = enabled;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Offline mode ${enabled ? "enabled" : "disabled"}')),
    );
  }

  Future<void> _checkModelsDownloadedPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _modelsDownloaded = prefs.getBool('modelsDownloaded') ?? false;
    });
  }

  Future<void> _downloadModels() async {
    if (!mounted) return;
    setState(() => _isDownloading = true);
    
    // Simulate download
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modelsDownloaded', true);

    if (!mounted) return;
    setState(() {
      _modelsDownloaded = true;
      _isDownloading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Offline models downloaded successfully!'),
          backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline Mode'),
        // ⭐️ FIXED: Removed hardcoded colors. Inherits from Theme now.
        elevation: 1,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          SwitchListTile(
            title: const Text('Enable Offline Mode'),
            subtitle: const Text('Use downloaded models when offline'),
            value: _offlineModeEnabled,
            onChanged: _saveOfflinePreference,
            secondary: Icon(Icons.offline_bolt_outlined, color: primaryColor),
            activeColor: primaryColor,
          ),
          const Divider(height: 20),
          ListTile(
            leading:
                Icon(Icons.download_for_offline_outlined, color: primaryColor),
            title: const Text('Offline Models'),
            subtitle: Text(_modelsDownloaded
                ? 'Models downloaded'
                : 'Download required for offline use'),
            trailing: _isDownloading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : ElevatedButton.icon(
                    icon: Icon(
                        _modelsDownloaded ? Icons.check : Icons.download,
                        size: 18),
                    label: Text(_modelsDownloaded ? 'Downloaded' : 'Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _modelsDownloaded ? Colors.grey : primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    onPressed: _modelsDownloaded || _isDownloading
                        ? null
                        : _downloadModels,
                  ),
          ),
        ],
      ),
    );
  }
}