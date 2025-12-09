import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/attendance_provider.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // Default: bulan ini (tanggal 1 sampai hari ini)
  late DateTime _startDate = _getDefaultStartDate();
  late DateTime _endDate = _getDefaultEndDate();

  static DateTime _getDefaultStartDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  static DateTime _getDefaultEndDate() {
    return DateTime.now();
  }

  @override
  void initState() {
    super.initState();
    // Set default ke bulan ini
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = now;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendance(
        startDate: _startDate,
        endDate: _endDate,
      );
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
      });
      
      // Reload attendance dengan date range baru
      Provider.of<AttendanceProvider>(context, listen: false).loadAttendance(
        startDate: _startDate,
        endDate: _endDate,
      );
    }
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

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'late':
        return Icons.access_time;
      case 'absent':
        return Icons.cancel;
      case 'leave':
        return Icons.beach_access;
      case 'sick':
        return Icons.medical_services;
      case 'remote':
        return Icons.home;
      default:
        return Icons.help;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Kehadiran'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Pilih Rentang Tanggal',
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
          // Attendance List
          Expanded(
            child: Consumer<AttendanceProvider>(
              builder: (context, attendanceProvider, _) {
          if (attendanceProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (attendanceProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    attendanceProvider.error!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                  onPressed: () {
                    attendanceProvider.loadAttendance(
                      startDate: _startDate,
                      endDate: _endDate,
                    );
                  },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final recent = attendanceProvider.recentAttendance;
          final today = attendanceProvider.todayAttendance;

          // Filter: jika today ada di recent, jangan tampilkan duplikat
          final filteredRecent = recent.where((record) {
            if (today != null && record.id == today.id) {
              return false; // Skip today dari recent list
            }
            return true;
          }).toList();

          if (filteredRecent.isEmpty && today == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada riwayat kehadiran',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => attendanceProvider.loadAttendance(
              startDate: _startDate,
              endDate: _endDate,
            ),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (today != null) ...[
                  Card(
                    color: Colors.blue[50],
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _getStatusIcon(today.status),
                                color: _getStatusColor(today.status),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hari Ini',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildAttendanceRow('Tanggal', DateFormat('dd MMMM yyyy').format(DateTime.parse(today.date))),
                          if (today.checkIn != null)
                            _buildAttendanceRow('Check-In', today.checkIn!),
                          if (today.checkOut != null)
                            _buildAttendanceRow('Check-Out', today.checkOut!),
                          const SizedBox(height: 8),
                          Chip(
                            label: Text(today.status.toUpperCase()),
                            backgroundColor: _getStatusColor(today.status).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _getStatusColor(today.status),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (filteredRecent.isNotEmpty) ...[
                  Text(
                    'Riwayat',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  ...filteredRecent.map((record) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: _getStatusColor(record.status).withOpacity(0.2),
                            child: Icon(
                              _getStatusIcon(record.status),
                              color: _getStatusColor(record.status),
                            ),
                          ),
                          title: Text(
                            DateFormat('dd MMMM yyyy').format(DateTime.parse(record.date)),
                          ),
                          subtitle: Text(
                            '${record.checkIn ?? '-'} - ${record.checkOut ?? '-'}',
                          ),
                          trailing: Chip(
                            label: Text(record.status.toUpperCase()),
                            backgroundColor: _getStatusColor(record.status).withOpacity(0.2),
                            labelStyle: TextStyle(
                              color: _getStatusColor(record.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      )),
                ],
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

  Widget _buildAttendanceRow(String label, String value) {
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
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

