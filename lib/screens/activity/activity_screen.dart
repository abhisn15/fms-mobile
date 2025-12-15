import 'package:flutter/material.dart';
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
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ActivityProvider>(context, listen: false).loadActivities();
    });
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
          // Activity List
          Expanded(
            child: Consumer<ActivityProvider>(
              builder: (context, activityProvider, _) {
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

                // Tampilkan semua aktivitas tanpa filter tanggal
                // Combine all activities for pagination
                final allFilteredActivities = <DailyActivity>[];
                if (today != null) {
                  allFilteredActivities.add(today);
                }
                allFilteredActivities.addAll(recent);

                // Calculate pagination
                final totalItems = allFilteredActivities.length;
                final totalPages = (totalItems / _itemsPerPage).ceil();
                final startIndex = (_currentPage - 1) * _itemsPerPage;
                final endIndex = startIndex + _itemsPerPage;
                final paginatedActivities = allFilteredActivities.sublist(
                  startIndex.clamp(0, totalItems),
                  endIndex.clamp(0, totalItems),
                );

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
                      // Pagination
                      if (totalPages > 1)
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
                                'Halaman $_currentPage dari $totalPages',
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
              child: Text(
                DateFormat('dd MMMM yyyy').format(DateTime.parse(activity.date)),
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
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
        trailing: PopupMenuButton<String>(
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
                      final fullUrl = ApiConfig.getImageUrl(url);
                      return GestureDetector(
                        onTap: () {
                          // Show full screen image dengan aspect ratio yang benar
                          showDialog(
                            context: context,
                            builder: (context) => FullScreenImageDialog.network(
                              imageUrl: fullUrl,
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 120,
                            height: 160, // 120 * 4/3 untuk portrait (lebih tinggi)
                            child: Image.network(
                              fullUrl,
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

