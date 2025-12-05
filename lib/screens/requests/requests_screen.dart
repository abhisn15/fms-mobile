import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/request_provider.dart';
import 'request_form_screen.dart';
import '../../models/request_model.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RequestProvider>(context, listen: false).loadRequests();
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
        return Colors.orange;
      case 'berlangsung':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
        return Icons.access_time;
      case 'berlangsung':
        return Icons.event;
      default:
        return Icons.help;
    }
  }

  String _getTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'izin':
        return 'Izin';
      case 'cuti':
        return 'Cuti';
      case 'sakit':
        return 'Sakit';
      default:
        return type;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Request'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => const RequestFormScreen(),
                ),
              );
              if (result == true && mounted) {
                Provider.of<RequestProvider>(context, listen: false)
                    .loadRequests();
              }
            },
          ),
        ],
      ),
      body: Consumer<RequestProvider>(
        builder: (context, requestProvider, _) {
          if (requestProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (requestProvider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    requestProvider.error!,
                    style: TextStyle(color: Colors.red[700]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      requestProvider.loadRequests();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }

          final requests = requestProvider.requests;

          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.request_quote_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada request',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RequestFormScreen(),
                        ),
                      );
                      if (result == true && mounted) {
                        requestProvider.loadRequests();
                      }
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Buat Request'),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => requestProvider.loadRequests(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: requests.map((request) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getStatusColor(request.status).withOpacity(0.2),
                        child: Icon(
                          _getStatusIcon(request.status),
                          color: _getStatusColor(request.status),
                        ),
                      ),
                      title: Text(_getTypeLabel(request.type)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(request.reason),
                          const SizedBox(height: 4),
                          Text(
                            '${DateFormat('dd MMM yyyy').format(DateTime.parse(request.startDate))} - ${DateFormat('dd MMM yyyy').format(DateTime.parse(request.endDate))}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      trailing: Chip(
                        label: Text(request.status.toUpperCase()),
                        backgroundColor: _getStatusColor(request.status).withOpacity(0.2),
                        labelStyle: TextStyle(
                          color: _getStatusColor(request.status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      isThreeLine: true,
                    ),
                  )).toList(),
            ),
          );
        },
      ),
    );
  }
}

