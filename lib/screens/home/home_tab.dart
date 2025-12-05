import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/shift_model.dart';
import '../camera/camera_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/animated_button.dart';
import '../../widgets/shimmer_loading.dart';
import '../../config/api_config.dart';
import '../../services/profile_service.dart';
import '../../main.dart' show navigatorKey;
import 'dart:io';
import 'dart:async';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  Timer? _durationTimer;
  AnimationController? _greetingController;
  AnimationController? _profileController;
  Animation<double>? _greetingFadeAnimation;
  Animation<Offset>? _greetingSlideAnimation;
  final ProfileService _profileService = ProfileService();

  void _initializeAnimations() {
    if (_greetingController == null) {
      _greetingController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 800),
      );
      _greetingFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _greetingController!, curve: Curves.easeOut),
      );
      _greetingSlideAnimation = Tween<Offset>(
        begin: const Offset(0, -0.3),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _greetingController!, curve: Curves.easeOut));
    }
    
    if (_profileController == null) {
      _profileController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 600),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    
    debugPrint('[HomeTab] Initializing...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeTab] Loading initial data...');
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendance();
      Provider.of<ShiftProvider>(context, listen: false).loadShifts();
      Provider.of<RequestProvider>(context, listen: false).loadRequests();
      // Start animations
      _greetingController?.forward();
      _profileController?.forward();
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _greetingController?.dispose();
    _profileController?.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Pagi';
    } else if (hour >= 12 && hour < 15) {
      return 'Siang';
    } else if (hour >= 15 && hour < 19) {
      return 'Sore';
    } else {
      return 'Malam';
    }
  }

  Future<void> _updateProfilePhoto() async {
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(title: 'Ambil Foto Profil'),
      ),
    );

    if (photo != null && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final result = await _profileService.updateProfilePhoto(photo);

      if (mounted) {
        if (result['success'] == true) {
          final photoUrl = result['data']['photoUrl'] as String?;
          if (photoUrl != null) {
            authProvider.updateUserPhoto(photoUrl);
          } else {
            // Reload user data if photoUrl not in response
            await authProvider.refreshUser();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto profil berhasil diunggah'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'Gagal mengunggah foto profil'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildProfileIcon(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: GestureDetector(
            onTap: () => _showProfileMenu(context, user),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(ApiConfig.getImageUrl(user.photoUrl!))
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.name[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showProfileMenu(BuildContext context, user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Profile Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Theme.of(context).primaryColor,
                      Theme.of(context).primaryColor.withOpacity(0.8),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _updateProfilePhoto();
                      },
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white,
                            backgroundImage: user.photoUrl != null
                                ? NetworkImage(ApiConfig.getImageUrl(user.photoUrl!))
                                : null,
                            child: user.photoUrl == null
                                ? Text(
                                    user.name[0].toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).primaryColor,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                          if (user.team != null || user.title != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${user.team ?? ''}${user.team != null && user.title != null ? ' • ' : ''}${user.title ?? ''}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Menu Items
              _buildMenuTile(
                context,
                icon: Icons.person_outline,
                title: 'Edit Profil',
                subtitle: 'Ubah informasi profil',
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to profile screen for editing
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(startInEditMode: true),
                    ),
                  );
                },
              ),
              _buildMenuTile(
                context,
                icon: Icons.settings_outlined,
                title: 'Pengaturan',
                subtitle: 'Pengaturan aplikasi',
                onTap: () {
                  Navigator.pop(context);
                  _showSettings(context);
                },
              ),
              _buildMenuTile(
                context,
                icon: Icons.info_outline,
                title: 'Tentang',
                subtitle: 'Informasi aplikasi',
                onTap: () {
                  Navigator.pop(context);
                  _showAbout(context);
                },
              ),
              const Divider(height: 1),
              _buildMenuTile(
                context,
                icon: Icons.logout,
                title: 'Logout',
                subtitle: 'Keluar dari akun',
                iconColor: Colors.red,
                textColor: Colors.red,
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout(context);
                },
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMenuTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    final defaultColor = Colors.grey[800]!;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (iconColor ?? Theme.of(context).primaryColor).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? Theme.of(context).primaryColor,
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor ?? defaultColor,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: Colors.grey[400],
      ),
      onTap: onTap,
    );
  }

  void _showSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pengaturan'),
        content: const Text('Fitur pengaturan akan segera hadir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tentang Aplikasi'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Atenim Mobile',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('Aplikasi mobile untuk manajemen karyawan'),
            SizedBox(height: 16),
            Text('Versi: 1.0.0'),
            SizedBox(height: 8),
            Text('© 2025 Atenim Workforce'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Get AuthProvider before showing dialog to avoid context issues after dialog closes
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Apakah Anda yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await authProvider.logout();
      
      // Use navigatorKey for safer navigation after logout
      // Wait a bit to ensure state is updated
      await Future.delayed(const Duration(milliseconds: 100));
      
      final navContext = navigatorKey.currentContext;
      if (navContext != null && mounted) {
        Navigator.of(navContext).pushNamedAndRemoveUntil('/login', (route) => false);
      } else if (mounted) {
        // Fallback: try using original context if navigatorKey is not available
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      }
    }
  }

  Widget _buildGreeting() {
    _initializeAnimations();
    
    if (_greetingFadeAnimation == null || _greetingSlideAnimation == null) {
      return const SizedBox.shrink();
    }
    
    return FadeTransition(
      opacity: _greetingFadeAnimation!,
      child: SlideTransition(
        position: _greetingSlideAnimation!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wb_sunny,
                  color: Theme.of(context).primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat ${_getGreeting()}!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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

  String _formatDuration(String? checkInTime) {
    if (checkInTime == null || checkInTime.isEmpty) return '0 jam 0 menit';
    
    try {
      final now = DateTime.now();
      // Parse waktu check-in (format: HH:mm)
      final parts = checkInTime.split(':');
      if (parts.length < 2) return '0 jam 0 menit';
      
      final checkInHour = int.parse(parts[0]);
      final checkInMinute = int.parse(parts[1]);
      
      final checkInWithDate = DateTime(
        now.year,
        now.month,
        now.day,
        checkInHour,
        checkInMinute,
      );
      
      final diff = now.difference(checkInWithDate);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      
      return '$hours jam $minutes menit';
    } catch (e) {
      return '0 jam 0 menit';
    }
  }

  Future<void> _handleCheckIn() async {
    debugPrint('[HomeTab] Check-in button pressed');
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final shifts = shiftProvider.shifts;
    final todayShift = shiftProvider.todayShift;
    
    // Jika ada shift yang di-assign hari ini, gunakan itu
    DailyShift? selectedShift = todayShift;
    if (selectedShift == null && shifts.isNotEmpty) {
      // Jika tidak ada shift yang di-assign, pilih shift pertama
      selectedShift = shifts.first;
    }

    if (selectedShift == null) {
      debugPrint('[HomeTab] ✗ No shift available');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada shift yang tersedia')),
        );
      }
      return;
    }

    debugPrint('[HomeTab] Selected shift: ${selectedShift.name} (${selectedShift.id})');
    debugPrint('[HomeTab] Opening camera for check-in selfie...');

    // Buka kamera untuk selfie
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          title: 'Ambil Selfie untuk Check-In',
        ),
      ),
    );

    if (photo != null && mounted) {
      debugPrint('[HomeTab] Photo captured: ${photo.path}');
      debugPrint('[HomeTab] Submitting check-in...');
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      final success = await attendanceProvider.checkIn(
        photo: photo,
        shiftId: selectedShift.id,
      );

      if (mounted) {
        debugPrint('[HomeTab] Check-in result: $success');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Check-in berhasil'
                : attendanceProvider.error ?? 'Check-in gagal'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        
        if (success) {
          debugPrint('[HomeTab] Starting duration timer...');
          // Start duration timer
          _startDurationTimer();
        }
      }
    } else {
      debugPrint('[HomeTab] Photo capture cancelled or widget unmounted');
    }
  }

  Future<void> _handleCheckOut() async {
    debugPrint('[HomeTab] Check-out button pressed');
    debugPrint('[HomeTab] Opening camera for check-out selfie...');

    // Buka kamera untuk selfie
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          title: 'Ambil Selfie untuk Check-Out',
        ),
      ),
    );

    if (photo != null && mounted) {
      debugPrint('[HomeTab] Photo captured: ${photo.path}');
      debugPrint('[HomeTab] Submitting check-out...');
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      final success = await attendanceProvider.checkOut(photo: photo);

      if (mounted) {
        debugPrint('[HomeTab] Check-out result: $success');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Check-out berhasil'
                : attendanceProvider.error ?? 'Check-out gagal'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
        
        if (success) {
          debugPrint('[HomeTab] Cancelling duration timer...');
          _durationTimer?.cancel();
        }
      }
    } else {
      debugPrint('[HomeTab] Photo capture cancelled or widget unmounted');
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Trigger rebuild untuk update duration
        });
      } else {
        timer.cancel();
      }
    });
  }

  Widget _buildCheckInPanel(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, _) {
        final todayShift = shiftProvider.todayShift;
        final shifts = shiftProvider.shifts;
        final hasAssignedShift = todayShift != null;
        
        return AnimatedCard(
          delay: 0,
          elevation: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.green[400]!,
                          Colors.green[600]!,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.login,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Check-In',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          'Ambil selfie dan bagikan lokasi untuk check-in',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Shift Selection
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SHIFT MASTER',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[600],
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (hasAssignedShift) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: todayShift.color != null
                                    ? Color(int.parse(
                                        'FF${todayShift.color!.replaceAll('#', '')}',
                                        radix: 16))
                                    : Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${todayShift.name} (${todayShift.code})',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    '${todayShift.startTime} - ${todayShift.endTime}',
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Di-assign Admin',
                                style: TextStyle(
                                  color: Colors.blue[900],
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⚠️ Shift ini sudah di-assign oleh admin/supervisor. Anda tidak dapat memilih shift lain.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                    ] else if (shifts.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Pilih Shift',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: shifts.map((shift) {
                          return DropdownMenuItem(
                            value: shift.id,
                            child: Text(
                              '${shift.name} (${shift.code}) - ${shift.startTime} - ${shift.endTime}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Shift akan dipilih saat check-in
                        },
                      ),
                    ] else ...[
                      Text(
                        'Belum ada shift yang bisa dipilih.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Check-In Button
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  if (attendanceProvider.isLoading) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return AnimatedButton(
                    width: double.infinity,
                    onPressed: (hasAssignedShift == false && shifts.isEmpty)
                        ? null
                        : _handleCheckIn,
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    icon: Icons.login,
                    child: const Text('Check-In'),
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Lokasi GPS direkam otomatis saat Anda menekan tombol Check-In',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckOutPanel(BuildContext context, AttendanceRecord today) {
    return AnimatedCard(
      delay: 0,
      elevation: 6,
      color: Colors.blue[50],
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue[100]!,
                  Colors.blue[50]!,
                ],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.blue[400]!,
                        Colors.blue[600]!,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Waktu Berlangsung',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDuration(today.checkIn),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.login, size: 14, color: Colors.blue[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Check-in: ${today.checkIn ?? '-'}',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Consumer<AttendanceProvider>(
            builder: (context, attendanceProvider, _) {
              if (attendanceProvider.isLoading) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange[300],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ),
                );
              }
              
              return AnimatedButton(
                width: double.infinity,
                onPressed: _handleCheckOut,
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                icon: Icons.logout,
                child: const Text('Check-Out'),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.camera_alt, size: 14, color: Colors.orange[700]),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Selfie wajib diambil untuk check-out',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange[700],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context, String errorMessage, {VoidCallback? onDismiss}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[300]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red[900],
                fontSize: 13,
              ),
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: Icon(Icons.close, color: Colors.red[700], size: 18),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      case 'leave':
        return Colors.blue;
      case 'sick':
        return Colors.purple;
      case 'remote':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Day',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withOpacity(0.8),
              ],
            ),
          ),
        ),
        actions: [
          _buildProfileIcon(context),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Provider.of<AttendanceProvider>(context, listen: false)
              .loadAttendance();
          await Provider.of<ShiftProvider>(context, listen: false).loadShifts();
          await Provider.of<RequestProvider>(context, listen: false).loadRequests();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Greeting
              _buildGreeting(),
              // Error Banner (jika ada error dari provider)
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  if (attendanceProvider.error != null) {
                    return _buildErrorBanner(
                      context,
                      attendanceProvider.error!,
                      onDismiss: () {
                        // Clear error saat dismiss
                        // Note: Provider tidak memiliki method clearError, jadi kita biarkan saja
                        // Error akan hilang saat data berhasil di-load
                      },
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              Consumer<ShiftProvider>(
                builder: (context, shiftProvider, _) {
                  if (shiftProvider.error != null) {
                    return _buildErrorBanner(
                      context,
                      shiftProvider.error!,
                      onDismiss: () {},
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              // Check-In Panel
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  final today = attendanceProvider.todayAttendance;
                  final hasCheckedIn = today?.checkIn != null;
                  final hasCheckedOut = today?.checkOut != null;

                  if (!hasCheckedIn && !hasCheckedOut) {
                    return _buildCheckInPanel(context);
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              // Check-Out Panel
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  final today = attendanceProvider.todayAttendance;
                  final hasCheckedIn = today?.checkIn != null;
                  final hasCheckedOut = today?.checkOut != null;

                  if (hasCheckedIn && !hasCheckedOut) {
                    return _buildCheckOutPanel(context, today!);
                  }
                  return const SizedBox.shrink();
                },
              ),

              // Status Card (jika sudah check-out)
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  final today = attendanceProvider.todayAttendance;
                  final hasCheckedOut = today?.checkOut != null;

                  if (hasCheckedOut) {
                    return AnimatedCard(
                      delay: 0,
                      color: Colors.green[50],
                      elevation: 4,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.green[700],
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Check-in & Check-out selesai',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[900],
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Check-in: ${today?.checkIn ?? '-'} | Check-out: ${today?.checkOut ?? '-'}',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              const SizedBox(height: 24),
              
              // Shift Info
              Consumer<ShiftProvider>(
                builder: (context, shiftProvider, _) {
                  final todayShift = shiftProvider.todayShift;
                  if (todayShift != null) {
                    final shiftColor = todayShift.color != null
                        ? Color(int.parse(
                            'FF${todayShift.color!.replaceAll('#', '')}',
                            radix: 16))
                        : Colors.blue;
                    
                    return AnimatedCard(
                      delay: 100,
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: shiftColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.schedule,
                                  color: shiftColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Shift Hari Ini',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: shiftColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: shiftColor.withOpacity(0.5),
                                      blurRadius: 4,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${todayShift.name} (${todayShift.code})',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${todayShift.startTime} - ${todayShift.endTime}',
                                      style: TextStyle(
                                        color: Colors.grey[700],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.blue[400]!,
                                      Colors.blue[600]!,
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.blue.withOpacity(0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  'Di-assign Admin',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              const SizedBox(height: 24),
              
              // Attendance Widget
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  final today = attendanceProvider.todayAttendance;
                  final recent = attendanceProvider.recentAttendance;
                  
                  if (attendanceProvider.isLoading && today == null) {
                    return AnimatedCard(
                      delay: 200,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShimmerLoading(width: 150, height: 20),
                          const SizedBox(height: 8),
                          ShimmerLoading(width: 200, height: 16),
                          const SizedBox(height: 16),
                          ShimmerLoading(width: double.infinity, height: 80),
                        ],
                      ),
                    );
                  }
                  
                  return AnimatedCard(
                    delay: 200,
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.purple[400]!,
                                    Colors.purple[600]!,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.calendar_today,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Attendance Kamu',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  Text(
                                    'Realtime status & riwayat 10 hari',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Today Status
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.grey[50]!,
                                Colors.grey[100]!,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hari ini',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (today != null) ...[
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            _getStatusColor(today.status).withOpacity(0.3),
                                            _getStatusColor(today.status).withOpacity(0.1),
                                          ],
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: _getStatusColor(today.status).withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        today.status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(today.status),
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        today.shiftId ?? '-',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.login, size: 16, color: Colors.green[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      today.checkIn ?? "-",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Icon(Icons.arrow_forward, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 16),
                                    Icon(Icons.logout, size: 16, color: Colors.orange[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      today.checkOut ?? "-",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Belum ada absensi terekam.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Recent History
                        if (recent.isNotEmpty) ...[
                          const SizedBox(height: 20),
                          Text(
                            'Riwayat',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.3, // Reduced from 2.5 to give more vertical space
                            ),
                            itemCount: recent.length > 10 ? 10 : recent.length,
                            itemBuilder: (context, idx) {
                              final record = recent[idx];
                              return AnimatedCard(
                                delay: 300 + (idx * 50),
                                elevation: 2,
                                padding: const EdgeInsets.all(8), // Reduced from 10 to 8
                                color: Colors.white,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min, // Prevent overflow
                                  children: [
                                    Text(
                                      DateFormat('dd MMM yyyy').format(DateTime.parse(record.date)),
                                      style: TextStyle(
                                        fontSize: 9, // Reduced from 10 to 9
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4), // Reduced from 6 to 4
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Flexible(
                                          flex: 2,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), // Reduced padding
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  _getStatusColor(record.status).withOpacity(0.3),
                                                  _getStatusColor(record.status).withOpacity(0.1),
                                                ],
                                              ),
                                              borderRadius: BorderRadius.circular(6), // Reduced from 8
                                            ),
                                            child: Text(
                                              record.status.toUpperCase(),
                                              style: TextStyle(
                                                color: _getStatusColor(record.status),
                                                fontSize: 8, // Reduced from 9 to 8
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4), // Add spacing between elements
                                        Flexible(
                                          flex: 3,
                                          child: Text(
                                            '${record.checkIn ?? "-"} → ${record.checkOut ?? "-"}',
                                            style: TextStyle(
                                              fontSize: 8, // Reduced from 9 to 8
                                              color: Colors.grey[600],
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.right,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}