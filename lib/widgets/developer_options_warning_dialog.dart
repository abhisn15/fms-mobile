import 'package:flutter/material.dart';

class DeveloperOptionsWarningDialog {
  static Future<void> show(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Developer Options Active'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  'Developer options are currently enabled. '
                  'This may affect app performance and stability.',
                ),
                SizedBox(height: 16),
                Text(
                  'Features that may be affected:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('• Debug logging'),
                Text('• Network request logging'),
                Text('• Background service debugging'),
                Text('• Test data generation'),
                SizedBox(height: 16),
                Text(
                  'Consider disabling developer options for normal use.',
                  style: TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Keep Enabled'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text(
                'Disable',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                // Note: The actual disabling logic should be handled by the provider
                // This is just for UI feedback
              },
            ),
          ],
        );
      },
    );
  }
}
