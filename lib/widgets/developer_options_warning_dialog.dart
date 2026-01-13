import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/developer_options_provider.dart';

class DeveloperOptionsWarningDialog {
  static Future<void> show(
    BuildContext context, {
    required bool isDeveloperOptionsEnabled,
    required bool isMockLocationEnabled,
  }) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button to close
      builder: (BuildContext context) {
        // Hanya tampilkan warning jika mock location aktif
        // Developer options boleh aktif, tidak perlu warning
        const String title = '⚠️ Fake GPS Terdeteksi';
        const String mainMessage = 'Fake GPS (Mock Location) terdeteksi aktif.';
        const List<String> issues = ['Fake GPS (Mock Location) aktif'];

        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                  mainMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Fitur ini dapat digunakan untuk memanipulasi lokasi dan data absensi.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Masalah yang terdeteksi:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...issues.map((issue) => Padding(
                      padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(issue)),
                        ],
                      ),
                    )),
                const SizedBox(height: 16),
                const Text(
                  'Silakan matikan Fake GPS (Mock Location) di pengaturan developer options, lalu tekan tombol "Cek Ulang" untuk memverifikasi.',
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Buka Pengaturan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                // Open developer options settings via provider
                // User perlu masuk ke developer options untuk mematikan mock location
                final provider = Provider.of<DeveloperOptionsProvider>(context, listen: false);
                await provider.openDeveloperOptions();
              },
            ),
            TextButton(
              child: const Text('Cek Ulang'),
              onPressed: () async {
                // Cek apakah developer options sudah dimatikan
                final provider = Provider.of<DeveloperOptionsProvider>(context, listen: false);
                
                // Refresh status dari native Android
                await provider.refreshStatus();
                
                // Tunggu sebentar untuk memastikan status ter-update
                await Future.delayed(const Duration(milliseconds: 100));
                
                // Tutup dialog (akan muncul lagi otomatis jika masih aktif)
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
                
                // Jika sudah dimatikan, tidak perlu melakukan apa-apa lagi
                // Jika masih aktif, dialog akan muncul lagi otomatis dari periodic check
              },
            ),
          ],
        );
      },
    );
  }
}










