import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/version_model.dart';

class UpdateDialog extends StatelessWidget {
  final VersionData versionData;
  final bool isRequired;

  const UpdateDialog({
    Key? key,
    required this.versionData,
    this.isRequired = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !isRequired, // Prevent closing if required
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              isRequired ? Icons.warning : Icons.system_update,
              color: isRequired ? Colors.red : Colors.blue,
            ),
            const SizedBox(width: 8),
            Text(
              isRequired ? 'Update Wajib' : 'Update Tersedia',
              style: TextStyle(
                color: isRequired ? Colors.red : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Versi ${versionData.version} tersedia!',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (versionData.releaseNotes.isNotEmpty) ...[
              const Text(
                'Yang baru:',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                versionData.releaseNotes,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            if (isRequired) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Update ini wajib untuk melanjutkan menggunakan aplikasi.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (!isRequired)
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Nanti'),
            ),
          ElevatedButton(
            onPressed: () => _launchUpdateUrl(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRequired ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text(isRequired ? 'Update Sekarang' : 'Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUpdateUrl(BuildContext context) async {
    try {
      final url = versionData.updateUrl;
      if (url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('URL update tidak tersedia'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        // Don't pop the dialog if update is required
        if (!isRequired) {
          Navigator.of(context).pop(true);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Play Store'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error launching update URL: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error membuka Play Store'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<void> show({
    required BuildContext context,
    required VersionData versionData,
    required bool isRequired,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: !isRequired,
      builder: (context) => UpdateDialog(
        versionData: versionData,
        isRequired: isRequired,
      ),
    );

    // Handle result if needed
    if (result == true && !isRequired) {
      // User chose to update
      debugPrint('User chose to update');
    }
  }
}
