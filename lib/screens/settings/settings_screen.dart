import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/global_update_checker.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;
  bool _isLoadingVersion = false;
  Map<String, String?> _updateCheckInfo = {};

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    _loadUpdateCheckInfo();
  }

  Future<void> _loadPackageInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = packageInfo;
    });
  }

  Future<void> _loadUpdateCheckInfo() async {
    final info = await GlobalUpdateChecker.getUpdateCheckInfo();
    setState(() {
      _updateCheckInfo = info;
    });
  }

  Future<void> _checkForUpdates() async {
    setState(() {
      _isLoadingVersion = true;
    });

    try {
      await GlobalUpdateChecker.manualUpdateCheck(context);

      // Reload update check info
      await _loadUpdateCheckInfo();

      setState(() {
        _isLoadingVersion = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingVersion = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengecek update: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatLastCheck(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays} hari yang lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam yang lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} menit yang lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return 'Tidak diketahui';
    }
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Kebijakan Privasi'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Kebijakan Privasi Aplikasi Atenim',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  'Terakhir diperbarui: 1 Januari 2026',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 16),
                Text(
                  '1. Pengumpulan Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Aplikasi ini mengumpulkan data berikut untuk keperluan absensi dan tracking lokasi:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Informasi akun (nama, email, nomor telepon)\n'
                  '• Data absensi (waktu check-in/check-out, lokasi)\n'
                  '• Foto absensi untuk verifikasi\n'
                  '• Data lokasi GPS untuk tracking kehadiran',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 16),
                Text(
                  '2. Penggunaan Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Data yang dikumpulkan digunakan untuk:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Memproses absensi karyawan\n'
                  '• Melacak kehadiran dan lokasi kerja\n'
                  '• Menyediakan laporan kehadiran\n'
                  '• Meningkatkan keamanan dan akurasi data',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 16),
                Text(
                  '3. Keamanan Data',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Kami berkomitmen untuk melindungi data Anda dengan:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Enkripsi data dalam transit dan penyimpanan\n'
                  '• Akses terbatas hanya untuk personel yang berwenang\n'
                  '• Audit keamanan berkala\n'
                  '• Penyimpanan data sesuai regulasi yang berlaku',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 16),
                Text(
                  '4. Hak Pengguna',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Anda memiliki hak untuk:',
                  style: TextStyle(fontSize: 14),
                ),
                SizedBox(height: 4),
                Text(
                  '• Mengakses data pribadi Anda\n'
                  '• Meminta koreksi data yang tidak akurat\n'
                  '• Meminta penghapusan data\n'
                  '• Menarik persetujuan penggunaan data',
                  style: TextStyle(fontSize: 13),
                ),
                SizedBox(height: 16),
                Text(
                  '5. Kontak',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Untuk pertanyaan tentang kebijakan privasi ini, hubungi:\n'
                  'abhi.nugroho@mindotek.com',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  bool _isDebugMode() {
    // In production, this should return false
    // For now, always show reset button for testing
    return true;
  }

  Future<void> _contactSupport() async {
    const whatsappUrl = 'https://wa.me/6285174200764';
    final uri = Uri.parse(whatsappUrl);
    
    try {
      // Gunakan URL link langsung, akan membuka di browser atau WhatsApp jika terinstall
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          // App Info Section
          _buildSectionHeader('Informasi Aplikasi'),
          _buildInfoTile(
            icon: Icons.info,
            title: 'Nama Aplikasi',
            value: _packageInfo?.appName ?? 'Atenim Mobile',
          ),
          _buildInfoTile(
            icon: Icons.tag,
            title: 'Versi Aplikasi',
            value: _packageInfo?.version ?? 'Loading...',
          ),

          const Divider(),

          // Update Section
          _buildSectionHeader('Pembaruan'),
          ListTile(
            leading: const Icon(Icons.system_update, color: Colors.blue),
            title: const Text('Cek Update'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tap untuk cek versi terbaru'),
                if (_updateCheckInfo['lastCheck'] != null)
                  Text(
                    'Terakhir dicek: ${_formatLastCheck(_updateCheckInfo['lastCheck']!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
              ],
            ),
            trailing: _isLoadingVersion
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: _checkForUpdates,
          ),

          // Reset button for testing (only in debug mode)
          if (_isDebugMode()) ...[
            ListTile(
              leading: const Icon(Icons.refresh, color: Colors.orange),
              title: const Text('Reset Update State'),
              subtitle: const Text('Untuk testing dialog update'),
              onTap: () async {
                await GlobalUpdateChecker.resetUpdateDialogState();
                await _loadUpdateCheckInfo();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Update state direset'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
            ),
          ],

          const Divider(),

          // Account Section
          _buildSectionHeader('Akun'),
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return ListTile(
                leading: const Icon(Icons.person, color: Colors.green),
                title: const Text('Pengguna'),
                subtitle: Text(authProvider.user?.name ?? 'Tidak ada data'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              );
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Keluar'),
            subtitle: const Text('Keluar dari akun'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi'),
                  content: const Text('Apakah Anda yakin ingin keluar?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirmed == true && mounted) {
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                await authProvider.logout();

                // Navigate to login screen after logout
                if (mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              }
            },
          ),

          const Divider(),

          // About Section
          _buildSectionHeader('Tentang'),
          ListTile(
            leading: const Icon(Icons.support_agent, color: Colors.green),
            title: const Text('Hubungi Support'),
            subtitle: const Text('Hubungi developer via WhatsApp'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _contactSupport,
          ),
          ListTile(
            leading: const Icon(Icons.email, color: Colors.blue),
            title: const Text('Kontak'),
            subtitle: const Text('abhi.nugroho@mindotek.com'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip, color: Colors.grey),
            title: const Text('Kebijakan Privasi'),
            subtitle: const Text('Pelajari tentang data Anda'),
            onTap: () => _showPrivacyPolicyDialog(context),
          ),

          const SizedBox(height: 20),

          // Version Footer
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Atenim Mobile v${_packageInfo?.version ?? '1.0.0'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
        ),
      ),
    );
  }
}
