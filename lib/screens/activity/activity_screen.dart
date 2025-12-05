import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/activity_provider.dart';
import 'activity_form_screen.dart';
import '../../models/activity_model.dart';
import '../../config/api_config.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
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
      body: Consumer<ActivityProvider>(
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

          if (recent.isEmpty && today == null) {
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
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (today != null) ...[
                  _buildActivityCard(context, today, isToday: true),
                  const SizedBox(height: 16),
                ],
                if (recent.isNotEmpty) ...[
                  Text(
                    'Riwayat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...recent.map((activity) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _buildActivityCard(context, activity),
                      )),
                ],
              ],
            ),
          );
        },
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
              backgroundColor: _getSentimentColor(activity.sentiment).withOpacity(0.2),
              child: Icon(
                _getSentimentIcon(activity.sentiment),
                color: _getSentimentColor(activity.sentiment),
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
                _buildInfoRow('Summary', activity.summary),
                _buildInfoRow('Sentiment', activity.sentiment),
                _buildInfoRow('Focus Hours', '${activity.focusHours} jam'),
                if (activity.highlights.isNotEmpty)
                  _buildListSection('Highlights', activity.highlights),
                if (activity.blockers.isNotEmpty)
                  _buildListSection('Blockers', activity.blockers),
                if (activity.plans.isNotEmpty)
                  _buildListSection('Plans', activity.plans),
                if (activity.notes != null && activity.notes!.isNotEmpty)
                  _buildInfoRow('Notes', activity.notes!),
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
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          fullUrl,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              width: 100,
                              height: 100,
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
                              width: 100,
                              height: 100,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
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

  Widget _buildListSection(String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $item'),
              )),
        ],
      ),
    );
  }

  Color _getSentimentColor(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positif':
        return Colors.green;
      case 'negatif':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSentimentIcon(String sentiment) {
    switch (sentiment.toLowerCase()) {
      case 'positif':
        return Icons.sentiment_satisfied;
      case 'negatif':
        return Icons.sentiment_dissatisfied;
      default:
        return Icons.sentiment_neutral;
    }
  }
}

