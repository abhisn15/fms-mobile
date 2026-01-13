import 'package:flutter/material.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_provider.dart';
import '../../widgets/adaptive_image.dart';
import 'activity_form_screen.dart';
import '../../models/activity_model.dart';
import '../../config/api_config.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  // Helper untuk membedakan daily activity dan patroli
  bool _isPatroli(DailyActivity activity) {
    // Use the model's computed isPatroli property
    return activity.isPatroli;
  }
  // Default: bulan ini (tanggal 1 sampai hari ini)
  late DateTime _startDate = _getDefaultStartDate();
  late DateTime _endDate = _getDefaultEndDate();
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  static DateTime _getDefaultStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime _getDefaultEndDate() {
    return DateTime.now();
  }

  DateTime? _parseActivityDate(DailyActivity activity) {
    final parsedDate = DateTime.tryParse(activity.date);
    final createdAt = activity.createdAt.isNotEmpty
        ? DateTime.tryParse(activity.createdAt)?.toLocal()
        : null;
    if (parsedDate == null) {
      return createdAt;
    }
    if (createdAt == null) {
      return parsedDate;
    }
    final dateOnly = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);
    final createdOnly = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final diffDays = (createdOnly.difference(dateOnly).inDays).abs();
    if (diffDays <= 1) {
      return createdAt;
    }
    return parsedDate;
  }

  String? _formatActivityTime(DailyActivity activity) {
    if (activity.createdAt.isNotEmpty) {
      final createdAt = DateTime.tryParse(activity.createdAt)?.toLocal();
      if (createdAt != null) {
        return DateFormat('HH:mm').format(createdAt);
      }
    }
    final dateValue = activity.date;
    if (dateValue.contains('T') || dateValue.contains(':')) {
      final parsed = DateTime.tryParse(dateValue)?.toLocal();
      if (parsed != null) {
        return DateFormat('HH:mm').format(parsed);
      }
    }
    return null;
  }

  bool _isLocalPhotoUrl(String url) {
    return url.startsWith('file://');
  }

  String _resolveLocalPath(String url) {
    if (!url.startsWith('file://')) {
      return url;
    }
    try {
      return Uri.parse(url).toFilePath();
    } catch (_) {
      return url.replaceFirst('file://', '');
    }
  }

  @override
  void initState() {
    super.initState();
    // Set default ke bulan ini
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ActivityProvider>(context, listen: false).loadActivities();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != DateTimeRange(start: _startDate, end: _endDate)) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1; // Reset to first page
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aktivitas Harian'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const ActivityFormScreen(),
                ),
              );
              if (result == true && mounted) {
                Provider.of<ActivityProvider>(context, listen: false)
                    .loadActivities();
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Range Filter Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.blue[700], size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rentang Tanggal',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${DateFormat('dd MMM yyyy', 'id_ID').format(_startDate)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_endDate)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[900],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit, color: Colors.blue[700], size: 20),
                  onPressed: () => _selectDateRange(context),
                  tooltip: 'Ubah Rentang Tanggal',
                ),
              ],
            ),
          ),
          // Activity List
          Expanded(
            child: Consumer<ActivityProvider>(
              builder: (context, activityProvider, _) {
                debugPrint('[ActivityScreen] Consumer rebuilding - isLoading: ${activityProvider.isLoading}, error: ${activityProvider.error}');
                if (activityProvider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (activityProvider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          activityProvider.error!,
                          style: TextStyle(color: Colors.red[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            activityProvider.loadActivities();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final recent = activityProvider.recentActivities;
                final today = activityProvider.todayActivity;
                debugPrint('[ActivityScreen] Provider data - today: ${today?.summary}, recent: ${recent.length}');

                // Filter aktivitas berdasarkan tanggal
                final startDateOnly = DateTime(_startDate.year, _startDate.month, _startDate.day);
                final endDateOnly = DateTime(_endDate.year, _endDate.month, _endDate.day).add(const Duration(days: 1));
                
                // Combine all activities first (pending activities already merged in ActivityProvider)
                final allActivities = <DailyActivity>[];
                if (today != null) {
                  allActivities.add(today);
                  debugPrint('[ActivityScreen] Today activity: ${today.summary}, type: ${today.type}, isPatroli: ${today.isPatroli}');
                }
                allActivities.addAll(recent);

                // Filter: hanya tampilkan daily activity (bukan patroli)
                final dailyActivitiesOnly = allActivities.where((activity) => !_isPatroli(activity)).toList();
                debugPrint('[ActivityScreen] Total activities: ${allActivities.length}, Daily activities: ${dailyActivitiesOnly.length}');
                debugPrint('[ActivityScreen] Filtered ${allActivities.length} total activities to ${dailyActivitiesOnly.length} daily activities');
                
                // Filter by date range
                final allFilteredActivities = dailyActivitiesOnly.where((activity) {
                  try {
                    final activityDate = _parseActivityDate(activity);
                    if (activityDate == null) {
                      return true;
                    }
                    final activityDateOnly = DateTime(activityDate.year, activityDate.month, activityDate.day);
                    return activityDateOnly.isAfter(startDateOnly.subtract(const Duration(days: 1))) && 
                           activityDateOnly.isBefore(endDateOnly);
                  } catch (e) {
                    return false;
                  }
                }).toList();

                // Calculate pagination
                final totalItems = allFilteredActivities.length;
                final totalPages = totalItems > 0 ? (totalItems / _itemsPerPage).ceil() : 1;
                final startIndex = (_currentPage - 1) * _itemsPerPage;
                final endIndex = startIndex + _itemsPerPage;
                final paginatedActivities = totalItems > 0 ? allFilteredActivities.sublist(
                  startIndex.clamp(0, totalItems),
                  endIndex.clamp(0, totalItems),
                ) : <DailyActivity>[];

                // Separate today and recent for display
                DailyActivity? paginatedToday;
                List<DailyActivity> paginatedRecent = [];
                
                if (paginatedActivities.isNotEmpty) {
                  // Check if first item is today
                  if (today != null && paginatedActivities.first.id == today.id) {
                    paginatedToday = paginatedActivities.first;
                    paginatedRecent = paginatedActivities.skip(1).toList();
                  } else {
                    paginatedRecent = paginatedActivities;
                  }
                }

                if (allFilteredActivities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada aktivitas',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ActivityFormScreen(),
                        ),
                      );
                      if (result == true && mounted) {
                        activityProvider.loadActivities();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Aktivitas'),
                  ),
                ],
              ),
            );
          }

                return RefreshIndicator(
                  onRefresh: () => activityProvider.loadActivities(),
                  child: Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (paginatedToday != null) ...[
                              _buildActivityCard(context, paginatedToday, isToday: true),
                              const SizedBox(height: 16),
                            ],
                            if (paginatedRecent.isNotEmpty) ...[
                              Text(
                                'Riwayat',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              ...paginatedRecent.map((activity) => Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _buildActivityCard(context, activity),
                                  )),
                            ],
                          ],
                        ),
                      ),
                      // Pagination (always show if more than itemsPerPage)
                      if (totalItems > _itemsPerPage)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            border: Border(top: BorderSide(color: Colors.grey[200]!)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Menampilkan ${startIndex + 1}-${endIndex.clamp(0, totalItems)} dari $totalItems',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: _currentPage > 1
                                        ? () {
                                            setState(() {
                                              _currentPage--;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text(
                                    '$_currentPage / $totalPages',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right),
                                    onPressed: _currentPage < totalPages
                                        ? () {
                                            setState(() {
                                              _currentPage++;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildActivityCard(BuildContext context, DailyActivity activity, {bool isToday = false}) {
    final activityDate = _parseActivityDate(activity);
    final activityDateLabel = activityDate != null
        ? DateFormat('dd MMMM yyyy').format(activityDate)
        : (activity.date.isNotEmpty ? activity.date : 'Tanggal tidak tersedia');
    final activityTimeLabel = _formatActivityTime(activity);
    return Card(
      color: isToday ? Colors.blue[50] : null,
      child: ExpansionTile(
        leading: Stack(
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.withOpacity(0.2),
              child: const Icon(
                Icons.assignment,
                color: Colors.blue,
              ),
            ),
            // Read status indicator
            if (activity.isRead == true)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activityDateLabel,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  if (activityTimeLabel != null)
                    Text(
                      activityTimeLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            if (activity.isLocal)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.schedule, size: 10, color: Colors.orange[800]),
                    const SizedBox(width: 4),
                    Text(
                      'Pending - Tunggu Koneksi',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[800],
                  ),
                    ),
                  ],
                ),
              ),
            if (activity.isRead == true && activity.viewsCount != null && activity.viewsCount! > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green[100],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility, size: 12, color: Colors.green[800]),
                    const SizedBox(width: 2),
                    Text(
                      '${activity.viewsCount}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Text(
          activity.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: activity.isLocal
            ? const SizedBox.shrink()
            : PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert),
                onSelected: (value) async {
                  if (value == 'edit') {
                    final result = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ActivityFormScreen(activityId: activity.id),
                      ),
                    );
                    if (result == true && mounted) {
                      Provider.of<ActivityProvider>(context, listen: false).loadActivities();
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Hapus Aktivitas'),
                        content: const Text('Apakah Anda yakin ingin menghapus aktivitas ini?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Batal'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && mounted) {
                      final provider = Provider.of<ActivityProvider>(context, listen: false);
                      final success = await provider.deleteActivity(activity.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(success ? 'Aktivitas berhasil dihapus' : provider.error ?? 'Gagal menghapus aktivitas'),
                            backgroundColor: success ? Colors.green : Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Hapus', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Keterangan', activity.summary),
                if (activity.photoUrls != null && activity.photoUrls!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Foto:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: activity.photoUrls!.map((url) {
                      final isLocal = _isLocalPhotoUrl(url);
                      final localPath = isLocal ? _resolveLocalPath(url) : null;
                      final fullUrl = isLocal ? null : ApiConfig.getImageUrl(url);
                      return GestureDetector(
                        onTap: () {
                          // Show full screen image dengan aspect ratio yang benar
                          showDialog(
                            context: context,
                            builder: (context) => isLocal
                                ? FullScreenImageDialog.file(
                                    imageFile: File(localPath!),
                                  )
                                : FullScreenImageDialog.network(
                                    imageUrl: fullUrl!,
                                  ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 160, // 120 * 4/3 untuk portrait (lebih tinggi)
                            child: isLocal
                                ? Image.file(
                                    File(localPath!),
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                  )
                                : Image.network(
                                    fullUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey[400],
                                        ),
                                      );
                                    },
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    },
                                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                                      if (wasSynchronouslyLoaded) return child;
                                      return AnimatedOpacity(
                                        opacity: frame == null ? 0 : 1,
                                        duration: const Duration(milliseconds: 200),
                                        child: child,
                                      );
                                    },
                                  ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

}

