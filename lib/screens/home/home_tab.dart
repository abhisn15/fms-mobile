import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';
import '../../providers/shift_provider.dart';
import '../../providers/request_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/connectivity_provider.dart';
import '../../models/shift_model.dart';
import '../../models/attendance_model.dart';
import '../camera/camera_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/animated_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/shift_selection_dialog.dart';
import '../../config/api_config.dart';
import '../../utils/toast_helper.dart';
import 'dart:io';
import 'dart:async';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin, WidgetsBindingObserver {
  Timer? _durationTimer;
  DailyShift? _selectedShift; // Selected shift for check-in
  DateTime? _checkInDateTime; // Store parsed check-in datetime
  final ValueNotifier<String> _durationNotifier = ValueNotifier<String>('00 : 00 : 00');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    debugPrint('[HomeTab] Initializing...');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      debugPrint('[HomeTab] Loading initial data...');
      // Set connectivity provider untuk attendance provider
      final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
      final connectivityProvider = Provider.of<ConnectivityProvider>(context, listen: false);
      attendanceProvider.setConnectivityProvider(connectivityProvider);
      
      // Refresh user data to ensure it's up to date
      Provider.of<AuthProvider>(context, listen: false).refreshUser();
      // Load attendance dengan default bulan ini
      // Load dari cache dulu untuk instant display, lalu refresh dari API
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      attendanceProvider.loadAttendance(
        startDate: startDate,
        endDate: now,
        forceRefresh: false, // Load dari cache dulu untuk instant display
      ).then((_) {
        // Setelah data di-load (baik dari cache atau API), start timer
        if (mounted) {
          debugPrint('[HomeTab] Attendance loaded, checking and starting timer...');
          _checkAndStartTimer(attendanceProvider);
          
          // Refresh dari API di background untuk mendapatkan data terbaru
          attendanceProvider.loadAttendance(
            startDate: startDate,
            endDate: now,
            forceRefresh: true, // Force refresh dari API
          ).then((_) {
            // Setelah refresh dari API, update timer dengan data terbaru
            if (mounted) {
              debugPrint('[HomeTab] Attendance refreshed from API, updating timer...');
              _checkAndStartTimer(attendanceProvider);
            }
          });
        }
      });
      
      Provider.of<ShiftProvider>(context, listen: false).loadShifts();
      Provider.of<RequestProvider>(context, listen: false).loadRequests();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _durationTimer?.cancel();
    _durationNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Saat app kembali ke foreground, hitung durasi langsung dari database (tidak perlu timer di background)
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        debugPrint('[HomeTab] App resumed - calculating duration from database');
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        final today = attendanceProvider.todayAttendance;
        
        // Langsung hitung durasi dari database tanpa perlu reload (lebih cepat)
        if (today != null && today.checkIn != null && today.checkOut == null) {
          final checkInDateTime = _parseCheckInDateTime(today);
          if (checkInDateTime != null) {
            // Update duration langsung dari perhitungan waktu check-in sampai sekarang
            final currentDuration = _formatDuration(checkInDateTime);
            _durationNotifier.value = currentDuration;
            _checkInDateTime = checkInDateTime;
            // Restart timer untuk update real-time selanjutnya
            _startDurationTimer();
          }
        } else if (today != null && today.checkOut != null) {
          // Sudah check-out, hitung total durasi
          final checkInDateTime = _parseCheckInDateTime(today);
          if (checkInDateTime != null) {
            final checkOutDateTime = _parseCheckOutDateTime(today);
            final totalDuration = _formatDuration(checkInDateTime, checkOutDateTime: checkOutDateTime);
            _durationNotifier.value = totalDuration;
            _durationTimer?.cancel();
          }
        }
        
        // Refresh data dari API di background (tidak blocking)
        final now = DateTime.now();
        final startDate = DateTime(now.year, now.month, 1);
        attendanceProvider.loadAttendance(
          startDate: startDate,
          endDate: now,
          forceRefresh: true,
        ).then((_) {
          if (mounted) {
            _checkAndStartTimer(attendanceProvider);
          }
        });
      }
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      // App di background - stop timer untuk hemat baterai
      // Timer tidak perlu berjalan di background karena durasi akan dihitung ulang saat app resume
      debugPrint('[HomeTab] App paused/inactive - stopping timer to save battery');
      _durationTimer?.cancel();
    }
  }






  DateTime? _parseCheckInDateTime(AttendanceRecord? today) {
    if (today == null || today.checkIn == null || today.checkIn!.isEmpty) {
      return null;
    }
    
    try {
      final now = DateTime.now();
      final checkInTime = today.checkIn!;
      
      // Try parsing as ISO 8601 datetime first (e.g., "2024-01-15T08:30:00Z")
      try {
        final parsed = DateTime.parse(checkInTime);
        // If parsed successfully and has date info, use it
        if (parsed.year > 2000) {
          return parsed;
        }
      } catch (e) {
        // Not ISO format, continue to time-only parsing
      }
      
      // Parse waktu check-in (format: HH:mm atau HH:mm:ss)
      final parts = checkInTime.split(':');
      if (parts.length < 2) return null;
      
      final checkInHour = int.parse(parts[0]);
      final checkInMinute = int.parse(parts[1]);
      final checkInSecond = parts.length > 2 ? int.parse(parts[2]) : 0;
      
      // Use date from today's attendance record if available
      DateTime checkInDate;
      try {
        final recordDate = DateTime.parse(today.date);
        checkInDate = DateTime(
          recordDate.year,
          recordDate.month,
          recordDate.day,
          checkInHour,
          checkInMinute,
          checkInSecond,
        );
      } catch (e) {
        // Fallback to current date
        checkInDate = DateTime(
          now.year,
          now.month,
          now.day,
          checkInHour,
          checkInMinute,
          checkInSecond,
        );
      }
      
      return checkInDate;
    } catch (e) {
      debugPrint('[HomeTab] Error parsing check-in time: $e');
      return null;
    }
  }

  /// Format duration dari check-in sampai sekarang (jika belum check-out) atau sampai check-out (jika sudah check-out)
  String _formatDuration(DateTime? checkInDateTime, {DateTime? checkOutDateTime}) {
    if (checkInDateTime == null) return '00 : 00 : 00';
    
    try {
      // Jika sudah check-out, hitung dari check-in sampai check-out
      // Jika belum check-out, hitung dari check-in sampai sekarang
      final endTime = checkOutDateTime ?? DateTime.now();
      final diff = endTime.difference(checkInDateTime);
      
      // Handle negative duration (shouldn't happen, but just in case)
      if (diff.isNegative) return '00 : 00 : 00';
      
      final hours = diff.inHours.toString().padLeft(2, '0');
      final minutes = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final seconds = (diff.inSeconds % 60).toString().padLeft(2, '0');
      
      return '$hours : $minutes : $seconds';
    } catch (e) {
      return '00 : 00 : 00';
    }
  }

  /// Parse check-out datetime dari attendance record
  DateTime? _parseCheckOutDateTime(AttendanceRecord? today) {
    if (today == null || today.checkOut == null || today.checkOut!.isEmpty) {
      return null;
    }
    
    try {
      final now = DateTime.now();
      final checkOutTime = today.checkOut!;
      
      // Try parsing as ISO 8601 datetime first
      try {
        final parsed = DateTime.parse(checkOutTime);
        if (parsed.year > 2000) {
          return parsed;
        }
      } catch (e) {
        // Not ISO format, continue to time-only parsing
      }
      
      // Parse waktu check-out (format: HH:mm atau HH:mm:ss)
      final parts = checkOutTime.split(':');
      if (parts.length < 2) return null;
      
      final checkOutHour = int.parse(parts[0]);
      final checkOutMinute = int.parse(parts[1]);
      final checkOutSecond = parts.length > 2 ? int.parse(parts[2]) : 0;
      
      // Use date from today's attendance record
      DateTime checkOutDate;
      try {
        final recordDate = DateTime.parse(today.date);
        checkOutDate = DateTime(
          recordDate.year,
          recordDate.month,
          recordDate.day,
          checkOutHour,
          checkOutMinute,
          checkOutSecond,
        );
      } catch (e) {
        // Fallback to current date
        checkOutDate = DateTime(
          now.year,
          now.month,
          now.day,
          checkOutHour,
          checkOutMinute,
          checkOutSecond,
        );
      }
      
      return checkOutDate;
    } catch (e) {
      debugPrint('[HomeTab] Error parsing check-out time: $e');
      return null;
    }
  }

  void _checkAndStartTimer(AttendanceProvider attendanceProvider) {
    final today = attendanceProvider.todayAttendance;
    
    // Priority: Check if check-out exists first - stop timer immediately
    // Jika sudah check-out, tidak perlu timer real-time, cukup hitung total durasi dari database
    if (today != null && today.checkOut != null) {
      if (_durationTimer != null && _durationTimer!.isActive) {
        debugPrint('[HomeTab] Stopping timer - check-out detected, showing total duration from database');
        _durationTimer?.cancel();
      }
      // Parse check-in untuk menghitung total durasi (tidak perlu timer, cukup hitung sekali)
      final checkInDateTime = _parseCheckInDateTime(today);
      _checkInDateTime = checkInDateTime;
      // Update duration notifier dengan total durasi (fixed, tidak real-time)
      if (mounted && checkInDateTime != null) {
        final checkOutDateTime = _parseCheckOutDateTime(today);
        final totalDuration = _formatDuration(checkInDateTime, checkOutDateTime: checkOutDateTime);
        _durationNotifier.value = totalDuration;
      }
      return; // Don't start timer if checked out
    }
    
    // Only start timer if checked in and NOT checked out
    if (today != null && today.checkIn != null && today.checkOut == null) {
      // Parse check-in datetime dari database (selalu baca fresh dari database)
      final newCheckInDateTime = _parseCheckInDateTime(today);
      if (newCheckInDateTime != null) {
        // Selalu restart timer dengan data terbaru dari database
        // Ini memastikan timer selalu menghitung dari waktu check-in yang benar
        // bahkan setelah app di-close dan dibuka lagi
        final shouldRestart = _checkInDateTime != newCheckInDateTime || 
                             _durationTimer == null || 
                             !_durationTimer!.isActive;
        
        if (shouldRestart) {
          _checkInDateTime = newCheckInDateTime;
          debugPrint('[HomeTab] Starting/restarting duration timer from check-in: $_checkInDateTime');
          // Initialize duration notifier dengan durasi yang benar dari database
          // Durasi dihitung dari waktu check-in sampai sekarang (real-time)
          if (_checkInDateTime != null) {
            final currentDuration = _formatDuration(_checkInDateTime);
            _durationNotifier.value = currentDuration;
          }
          _startDurationTimer();
        }
      }
    } else {
      // No check-in detected
      if (_durationTimer != null && _durationTimer!.isActive) {
        debugPrint('[HomeTab] Stopping timer - no check-in detected');
        _durationTimer?.cancel();
      }
      _checkInDateTime = null;
      _durationNotifier.value = '00 : 00 : 00';
    }
  }

  Map<String, int> _calculateAttendanceStats(List<AttendanceRecord> recent) {
    int present = 0;
    int late = 0;
    int absent = 0;
    
    final now = DateTime.now();
    final currentMonth = now.month;
    final currentYear = now.year;
    
    for (var record in recent) {
      try {
        final recordDate = DateTime.parse(record.date);
        if (recordDate.month == currentMonth && recordDate.year == currentYear) {
          final status = record.status.toLowerCase();
          if (status == 'present') {
            present++;
          } else if (status == 'late') {
            late++;
          } else if (status == 'absent') {
            absent++;
          }
        }
      } catch (e) {
        // Skip invalid dates
        continue;
      }
    }
    
    return {'present': present, 'late': late, 'absent': absent};
  }



  Future<void> _handleCheckIn() async {
    debugPrint('[HomeTab] Check-in button pressed');
    final shiftProvider = Provider.of<ShiftProvider>(context, listen: false);
    final shifts = shiftProvider.shifts;
    final todayShift = shiftProvider.todayShift;
    
    // Validasi: Shift harus dipilih terlebih dahulu
    DailyShift? selectedShift = todayShift ?? _selectedShift;
    
    if (selectedShift == null) {
      debugPrint('[HomeTab] ✗ No shift selected');
      if (mounted) {
        if (shifts.isEmpty) {
          ToastHelper.showWarning(context, 'Tidak ada shift yang tersedia');
        } else {
          // Tampilkan dialog pilih shift
          final chosenShift = await showDialog<DailyShift>(
            context: context,
            builder: (context) => ShiftSelectionDialog(
              shifts: shifts,
              selectedShift: null,
              onShiftSelected: (shift) {
                Navigator.of(context).pop(shift);
              },
            ),
          );
          
          if (chosenShift == null) {
            // User membatalkan pemilihan shift
            return;
          }
          
          selectedShift = chosenShift;
          _selectedShift = chosenShift;
        }
      }
      
      if (selectedShift == null) {
        return; // Tidak bisa check-in tanpa shift
      }
    }

    debugPrint('[HomeTab] Selected shift: ${selectedShift.name} (${selectedShift.id})');
    debugPrint('[HomeTab] Opening camera for check-in selfie...');

    // Buka kamera untuk selfie (hanya kamera, tidak boleh galeri)
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          title: 'Ambil Selfie untuk Check-In',
          allowGallery: false, // Check-in hanya boleh kamera
        ),
      ),
    );

    if (photo != null && mounted) {
      debugPrint('[HomeTab] Photo captured: ${photo.path}');
      debugPrint('[HomeTab] Submitting check-in...');
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      
      try {
        final success = await attendanceProvider.checkIn(
          photo: photo,
          shiftId: selectedShift.id,
        );

        if (mounted) {
          debugPrint('[HomeTab] Check-in result: $success');
          if (success) {
            // Refresh attendance data untuk memastikan data terbaru
            final now = DateTime.now();
            final startDate = DateTime(now.year, now.month, 1);
            await attendanceProvider.loadAttendance(
              startDate: startDate,
              endDate: now,
              forceRefresh: true,
            );
            
            if (mounted) {
              ToastHelper.showSuccess(context, 'Check-in berhasil!');
              debugPrint('[HomeTab] Starting duration timer...');
              // Parse and start duration timer
              final today = attendanceProvider.todayAttendance;
              _checkInDateTime = _parseCheckInDateTime(today);
              _startDurationTimer();
            }
          } else {
            if (mounted) {
              ToastHelper.showError(context, attendanceProvider.error ?? 'Check-in gagal');
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeTab] Error during check-in: $e');
        if (mounted) {
          ToastHelper.showError(context, 'Terjadi kesalahan saat check-in: $e');
        }
      }
    } else {
      debugPrint('[HomeTab] Photo capture cancelled or widget unmounted');
    }
  }

  Future<void> _handleCheckOut() async {
    debugPrint('[HomeTab] Check-out button pressed');
    debugPrint('[HomeTab] Opening camera for check-out selfie...');

    // Buka kamera untuk selfie (hanya kamera, tidak boleh galeri)
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          title: 'Ambil Selfie untuk Check-Out',
          allowGallery: false, // Check-out hanya boleh kamera
        ),
      ),
    );

    if (photo != null && mounted) {
      debugPrint('[HomeTab] Photo captured: ${photo.path}');
      debugPrint('[HomeTab] Submitting check-out...');
      final attendanceProvider =
          Provider.of<AttendanceProvider>(context, listen: false);
      
      try {
        final success = await attendanceProvider.checkOut(photo: photo);

        if (mounted) {
          debugPrint('[HomeTab] Check-out result: $success');
          if (success) {
            // Refresh attendance data untuk memastikan data terbaru
            final now = DateTime.now();
            final startDate = DateTime(now.year, now.month, 1);
            await attendanceProvider.loadAttendance(
              startDate: startDate,
              endDate: now,
              forceRefresh: true,
            );
            
            if (mounted) {
              ToastHelper.showSuccess(context, 'Check-out berhasil!');
              // Stop timer immediately after successful check-out
              debugPrint('[HomeTab] Stopping duration timer after check-out');
              _durationTimer?.cancel();
              // Parse check-in untuk menghitung total durasi (tidak perlu timer lagi)
              final updatedToday = attendanceProvider.todayAttendance;
              _checkInDateTime = updatedToday != null ? _parseCheckInDateTime(updatedToday) : null;
              // Update duration notifier dengan total durasi (fixed)
              if (_checkInDateTime != null && updatedToday != null) {
                final checkOutDateTime = _parseCheckOutDateTime(updatedToday);
                final totalDuration = _formatDuration(_checkInDateTime, checkOutDateTime: checkOutDateTime);
                _durationNotifier.value = totalDuration;
              }
            }
          } else {
            if (mounted) {
              ToastHelper.showError(context, attendanceProvider.error ?? 'Check-out gagal');
            }
          }
        }
      } catch (e) {
        debugPrint('[HomeTab] Error during check-out: $e');
        if (mounted) {
          ToastHelper.showError(context, 'Terjadi kesalahan saat check-out: $e');
        }
      }
    } else {
      debugPrint('[HomeTab] Photo capture cancelled or widget unmounted');
    }
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    if (_checkInDateTime == null) {
      debugPrint('[HomeTab] Cannot start timer: _checkInDateTime is null');
      return;
    }
    
    debugPrint('[HomeTab] Starting duration timer from: $_checkInDateTime');
    // Timer hanya berjalan saat app aktif (foreground)
    // Saat app di background, timer akan di-stop dan durasi akan dihitung ulang saat resume
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      // Optimasi: hanya cek database setiap 5 detik untuk mengurangi beban
      // Tapi update UI setiap detik untuk smooth animation
      final shouldCheckDatabase = timer.tick % 5 == 0;
      
      if (shouldCheckDatabase) {
        // Cek data dari database setiap 5 detik (lebih efisien)
        final attendanceProvider = Provider.of<AttendanceProvider>(context, listen: false);
        final today = attendanceProvider.todayAttendance;
        
        // Check if still checked in
        if (today == null || today.checkIn == null || today.checkOut != null) {
          // Check-out detected, stop timer
          debugPrint('[HomeTab] Check-out detected, stopping timer');
          _checkInDateTime = null;
          timer.cancel();
          if (mounted) {
            // Update dengan total durasi jika sudah check-out
            if (today != null && today.checkOut != null) {
              final checkInDateTime = _parseCheckInDateTime(today);
              if (checkInDateTime != null) {
                final checkOutDateTime = _parseCheckOutDateTime(today);
                final totalDuration = _formatDuration(checkInDateTime, checkOutDateTime: checkOutDateTime);
                _durationNotifier.value = totalDuration;
              }
            } else {
              _durationNotifier.value = '00 : 00 : 00';
            }
          }
          return;
        }
        
        // Update check-in datetime jika berubah (jarang terjadi)
        final newCheckInDateTime = _parseCheckInDateTime(today);
        if (newCheckInDateTime != null && newCheckInDateTime != _checkInDateTime) {
          debugPrint('[HomeTab] Check-in datetime updated from database: $newCheckInDateTime');
          _checkInDateTime = newCheckInDateTime;
        }
      }
      
      // Update UI setiap detik (ringan, hanya perhitungan waktu)
      // Tidak perlu akses database setiap detik, cukup hitung dari _checkInDateTime yang sudah ada
      if (mounted && _checkInDateTime != null) {
        final duration = _formatDuration(_checkInDateTime);
        _durationNotifier.value = duration;
      }
    });
  }

  Widget _buildTodaysAttendanceCard(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, _) {
        final today = attendanceProvider.todayAttendance;
        final hasCheckedIn = today?.checkIn != null;
        final hasCheckedOut = today?.checkOut != null;
        
        // Check and start timer when attendance data changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndStartTimer(attendanceProvider);
        });
        
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header dengan gradient
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue[700]!,
                      Colors.blue[600]!,
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tanggal di paling atas
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Title dengan icon
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Kehadiran Hari Ini",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Working Time Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.blue[100]!,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[100],
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.timer_outlined,
                              color: Colors.blue[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Waktu Bekerja',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Use ValueListenableBuilder untuk hanya rebuild bagian duration saja
                                ValueListenableBuilder<String>(
                                  valueListenable: _durationNotifier,
                                  builder: (context, duration, _) {
                                    // Jika sudah check-out, gunakan total durasi (fixed)
                                    if (hasCheckedOut) {
                                      final totalDuration = _formatDuration(
                                        _checkInDateTime ?? _parseCheckInDateTime(today),
                                        checkOutDateTime: _parseCheckOutDateTime(today),
                                      );
                                      return Text(
                                        totalDuration,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[900],
                                          letterSpacing: 1.2,
                                        ),
                                      );
                                    }
                                    // Jika belum check-out, gunakan duration dari notifier (real-time)
                                    return Text(
                                      hasCheckedIn ? duration : '00 : 00 : 00',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                        letterSpacing: 1.2,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Location Section - Check-In and Check-Out
                    if (hasCheckedIn || hasCheckedOut) ...[
                      // Check-In Location
                      if (hasCheckedIn)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.green[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.login, size: 18, color: Colors.green[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lokasi Check-In',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green[900],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      today?.checkInLocation != null
                                          ? '${today!.checkInLocation!.lat.toStringAsFixed(6)}, ${today.checkInLocation!.lng.toStringAsFixed(6)}'
                                          : (today?.location != null && !hasCheckedOut
                                              ? '${today!.location!.lat.toStringAsFixed(6)}, ${today.location!.lng.toStringAsFixed(6)}'
                                              : 'Lokasi tidak tersedia'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Check-Out Location
                      if (hasCheckedOut)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.logout, size: 18, color: Colors.blue[700]),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Lokasi Check-Out',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      today?.checkOutLocation != null
                                          ? '${today!.checkOutLocation!.lat.toStringAsFixed(6)}, ${today.checkOutLocation!.lng.toStringAsFixed(6)}'
                                          : (today?.location != null
                                              ? '${today!.location!.lat.toStringAsFixed(6)}, ${today.location!.lng.toStringAsFixed(6)}'
                                              : 'Lokasi tidak tersedia'),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[700],
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ] else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_outlined, size: 18, color: Colors.grey[600]),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Lokasi akan direkam saat check-in',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Shift Selection (hanya muncul jika belum check-in)
                    if (!hasCheckedIn) ...[
                      const SizedBox(height: 16),
                      Text(
                        'SHIFT',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildShiftSelectionInCard(context),
                    ],
                    const SizedBox(height: 20),
                    // Warning text jika shift belum dipilih (hanya muncul jika belum check-in)
                    if (!hasCheckedIn)
                      _buildShiftWarning(context),
                    if (!hasCheckedIn) const SizedBox(height: 12),
                    // Check-In/Check-Out Button
                    if (!hasCheckedIn)
                      _buildCheckInButton(context)
                    else if (!hasCheckedOut)
                      _buildCheckOutButton(context)
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[50]!,
                              Colors.green[100]!,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.green[400],
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Check-in & Check-out selesai',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildShiftSelectionInCard(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, _) {
        final todayShift = shiftProvider.todayShift;
        final shifts = shiftProvider.shifts;
        final hasAssignedShift = todayShift != null;
        
        if (hasAssignedShift) {
          return Container(
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
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        '${todayShift.startTime} - ${todayShift.endTime}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Assigned',
                    style: TextStyle(
                      color: Colors.blue[900],
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        } else if (shifts.isNotEmpty) {
          return InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => ShiftSelectionDialog(
                  shifts: shifts,
                  selectedShift: _selectedShift,
                  onShiftSelected: (shift) {
                    setState(() {
                      _selectedShift = shift;
                    });
                  },
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _selectedShift != null ? Colors.blue[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _selectedShift != null ? Colors.blue[300]! : Colors.grey[300]!,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  if (_selectedShift != null) ...[
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _selectedShift!.color != null
                            ? Color(int.parse(
                                'FF${_selectedShift!.color!.replaceAll('#', '')}',
                                radix: 16))
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                      // Hanya warna, tanpa teks (menghilangkan nama shift di dalam lingkaran)
                      child: null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedShift!.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_selectedShift!.startTime} - ${_selectedShift!.endTime}',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pilih Shift',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  Icon(Icons.arrow_drop_down, color: Colors.grey[600]),
                ],
              ),
            ),
          );
        } else {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange[700], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Belum ada shift yang tersedia',
                    style: TextStyle(
                      color: Colors.orange[700],
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      },
    );
  }

  Widget _buildShiftWarning(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, _) {
        final shifts = shiftProvider.shifts;
        final todayShift = shiftProvider.todayShift;
        final hasAssignedShift = todayShift != null;
        
        // Hanya tampilkan warning jika shift belum dipilih
        if (hasAssignedShift || _selectedShift != null || shifts.isEmpty) {
          return const SizedBox.shrink();
        }
        
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.amber[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber[800], size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Silakan pilih shift terlebih dahulu sebelum melakukan check-in',
                  style: TextStyle(
                    color: Colors.amber[900],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCheckInButton(BuildContext context) {
    return Consumer<ShiftProvider>(
      builder: (context, shiftProvider, _) {
        final todayShift = shiftProvider.todayShift;
        final hasAssignedShift = todayShift != null;
        final hasSelectedShift = hasAssignedShift || _selectedShift != null;
        
        return Consumer<AttendanceProvider>(
          builder: (context, attendanceProvider, _) {
            final isLoading = attendanceProvider.isLoading;
            final isDisabled = !hasSelectedShift || isLoading;
            
            if (isLoading) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.green[300],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Memproses Check-In...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return ElevatedButton(
              onPressed: isDisabled ? null : _handleCheckIn,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? Colors.grey[400] : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: isDisabled ? 0 : 2,
                disabledBackgroundColor: Colors.grey[400],
                disabledForegroundColor: Colors.white70,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login, size: 20, color: isDisabled ? Colors.white70 : Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'Check-In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDisabled ? Colors.white70 : Colors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCheckOutButton(BuildContext context) {
    return Consumer<AttendanceProvider>(
      builder: (context, attendanceProvider, _) {
        final isLoading = attendanceProvider.isLoading;
        final today = attendanceProvider.todayAttendance;
        final hasCheckedOut = today?.checkOut != null;
        
        // Disable jika sudah check-out atau sedang loading
        final isDisabled = hasCheckedOut || isLoading;
        
        if (isLoading) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Memproses Check-Out...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return ElevatedButton(
          onPressed: isDisabled ? null : _handleCheckOut,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDisabled ? Colors.grey[400] : Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: isDisabled ? 0 : 2,
            disabledBackgroundColor: Colors.grey[400],
            disabledForegroundColor: Colors.white70,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout, 
                size: 20, 
                color: isDisabled ? Colors.white70 : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                hasCheckedOut ? 'Sudah Check-Out' : 'Check-Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDisabled ? Colors.white70 : Colors.white,
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildStatCard(BuildContext context, {Key? key, required int count, required String label, required Color color}) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final user = authProvider.user;
        if (user == null) return const SizedBox.shrink();
        
        // Calculate display name - ensure it's never empty
        // Handle cases where name might be empty or contain only whitespace
        String displayName = user.name.trim();
        if (displayName.isEmpty) {
          // Fallback to email username if name is empty
          if (user.email.isNotEmpty) {
            displayName = user.email.split('@')[0];
          } else {
            // Last resort fallback
            displayName = 'User';
          }
        }
        
        return Container(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: MediaQuery.of(context).padding.top + 6,
            bottom: 8,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.blue[700]!,
                Colors.blue[600]!,
              ],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(20),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Picture - Clickable
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.white,
                    backgroundImage: user.photoUrl != null
                        ? NetworkImage(ApiConfig.getImageUrl(user.photoUrl!))
                        : null,
                    child: user.photoUrl == null
                        ? Text(
                            (user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // User Info
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Nama user - always show name if available
                    // Jika nama terlalu panjang, akan otomatis dipotong dengan "..." di akhir
                    Text(
                      displayName,
                      key: ValueKey('user-name-${user.id}'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                        letterSpacing: 0.3,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 4),
                    // Title/jabatan
                    Text(
                      user.title ?? 'Employee',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.95),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                    ),
                  ],
                ),
              ),
              // Notification Bell
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white, size: 20),
                  onPressed: () {
                    _showNotificationUnderMaintenance(context);
                  },
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showNotificationUnderMaintenance(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.construction, color: Colors.orange[700], size: 24),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Notifikasi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.build_circle_outlined,
              size: 64,
              color: Colors.orange[400],
            ),
            const SizedBox(height: 16),
            const Text(
              'Fitur notifikasi sedang dalam pengembangan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Fitur ini akan segera hadir di update berikutnya',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Mengerti',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        flexibleSpace: _buildUserHeader(context),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh user data first
          await Provider.of<AuthProvider>(context, listen: false).refreshUser();
          // Load attendance dengan default bulan ini
          final now = DateTime.now();
          final startDate = DateTime(now.year, now.month, 1);
          await Provider.of<AttendanceProvider>(context, listen: false)
              .loadAttendance(startDate: startDate, endDate: now);
          await Provider.of<ShiftProvider>(context, listen: false).loadShifts();
          await Provider.of<RequestProvider>(context, listen: false).loadRequests();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Today's Attendance Card
              _buildTodaysAttendanceCard(context),
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

              const SizedBox(height: 20),
              
              // Total Attendance (Days) Section
              Consumer<AttendanceProvider>(
                builder: (context, attendanceProvider, _) {
                  final recent = attendanceProvider.recentAttendance;
                  final stats = _calculateAttendanceStats(recent);
                  
                  return AnimatedCard(
                    delay: 100,
                    elevation: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Attendance (Days)',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                context,
                                count: stats['present'] ?? 0,
                                label: 'Present',
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                count: stats['late'] ?? 0,
                                label: 'Late',
                                color: Colors.orange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatCard(
                                context,
                                count: stats['absent'] ?? 0,
                                label: 'Absent',
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 20),
              
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
                                    'Realtime status & riwayat sebulan',
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
                                      child: Consumer<ShiftProvider>(
                                        builder: (context, shiftProvider, _) {
                                          String shiftName = '-';
                                          if (today.shiftId != null) {
                                            // Cari shift dari todayShift atau dari shifts list
                                            DailyShift? shift;
                                            if (shiftProvider.todayShift?.id == today.shiftId) {
                                              shift = shiftProvider.todayShift;
                                            } else {
                                              try {
                                                shift = shiftProvider.shifts.firstWhere(
                                                  (s) => s.id == today.shiftId,
                                                );
                                              } catch (e) {
                                                shift = null;
                                              }
                                            }
                                            shiftName = shift?.name ?? '-';
                                          }
                                          return Text(
                                            'Shift: $shiftName',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey[700],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          );
                                        },
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Riwayat',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[700],
                                ),
                              ),
                              if (recent.length > 10)
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/attendance');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    'Lihat selengkapnya',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 2.3,
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