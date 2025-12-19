import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/request_provider.dart';
import '../models/request_model.dart';

class LeaveRequestBanner extends StatelessWidget {
  const LeaveRequestBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<RequestProvider>(
      builder: (context, requestProvider, _) {
        final requests = requestProvider.requests;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        
        // Find active leave request (status: approved atau berlangsung) that includes today
        LeaveRequest? activeRequest;
        for (final request in requests) {
          final status = request.status.toLowerCase();
          // Cek status approved atau berlangsung
          if (status == 'approved' || status == 'berlangsung') {
            try {
              final startDate = DateTime.parse(request.startDate);
              final endDate = DateTime.parse(request.endDate);
              final start = DateTime(startDate.year, startDate.month, startDate.day);
              final end = DateTime(endDate.year, endDate.month, endDate.day);
              
              // Check if today is within the leave request date range
              if (today.isAfter(start.subtract(const Duration(days: 1))) && 
                  today.isBefore(end.add(const Duration(days: 1)))) {
                activeRequest = request;
                break;
              }
            } catch (e) {
              // Skip invalid date formats
              continue;
            }
          }
        }
        
        if (activeRequest == null) {
          return const SizedBox.shrink();
        }
        
        String getTypeLabel(String type) {
          switch (type.toLowerCase()) {
            case 'izin':
              return 'Izin';
            case 'cuti':
              return 'Cuti';
            case 'sakit':
            case 'sick': // Handle both "sakit" and "sick" for compatibility
              return 'Sakit';
            default:
              return type;
          }
        }
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[200]!, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.event_available,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${getTypeLabel(activeRequest.type)} Berlangsung',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Anda sedang dalam ${getTypeLabel(activeRequest.type).toLowerCase()}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(activeRequest.startDate))} - ${DateFormat('dd MMM yyyy', 'id_ID').format(DateTime.parse(activeRequest.endDate))}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[900],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (activeRequest.reason.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.description, size: 16, color: Colors.blue[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              activeRequest.reason,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Anda tidak dapat melakukan check-in selama periode ini',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.amber[900],
                          fontWeight: FontWeight.w500,
                        ),
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
}

