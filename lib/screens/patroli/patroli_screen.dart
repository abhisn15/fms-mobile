import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../providers/activity_provider.dart';
import '../../models/activity_model.dart';
import '../../screens/camera/camera_screen.dart';
import '../../config/api_config.dart';
import 'dart:io';

class PatroliScreen extends StatefulWidget {
  const PatroliScreen({super.key});

  @override
  State<PatroliScreen> createState() => _PatroliScreenState();
}

class _PatroliScreenState extends State<PatroliScreen> {
  final List<SecurityCheckpoint> _defaultCheckpoints = [
    SecurityCheckpoint(
      id: 'cp-01',
      name: 'CP-01: Patroli Area Perimeter',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-02',
      name: 'CP-02: Cek CCTV & Sistem Keamanan',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-03',
      name: 'CP-03: Pemeriksaan Pintu & Jendela',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-04',
      name: 'CP-04: Cek Area Parkir',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-05',
      name: 'CP-05: Pemeriksaan Alat Pemadam Kebakaran',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-06',
      name: 'CP-06: Cek Log Pengunjung',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-07',
      name: 'CP-07: Patroli Area Dalam Gedung',
      completed: false,
    ),
    SecurityCheckpoint(
      id: 'cp-08',
      name: 'CP-08: Cek Sistem Alarm & Emergency',
      completed: false,
    ),
  ];

  final _summaryController = TextEditingController();
  final _notesController = TextEditingController();
  final Map<String, TextEditingController> _reasonControllers = {};
  List<SecurityCheckpoint> _checkpoints = [];
  bool _isSubmitting = false;
  String? _gettingLocationFor;

  @override
  void initState() {
    super.initState();
    _checkpoints = List.from(_defaultCheckpoints);
    // Initialize reason controllers
    for (var cp in _checkpoints) {
      _reasonControllers[cp.id] = TextEditingController();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ActivityProvider>(context, listen: false).loadActivities();
    });
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _notesController.dispose();
    for (var controller in _reasonControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _completeCheckpoint(int index) async {
    final checkpoint = _checkpoints[index];
    final reasonController = _reasonControllers[checkpoint.id];
    
    // Validasi: foto dan alasan wajib
    if (checkpoint.photoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto bukti wajib diambil untuk checkpoint ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    if (reasonController == null || reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan/findings wajib diisi untuk checkpoint ini'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _gettingLocationFor = checkpoint.id;
    });

    try {
      // Ambil GPS coordinates
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );

      // Update checkpoint dengan GPS dan reason
      setState(() {
        _checkpoints[index] = SecurityCheckpoint(
          id: checkpoint.id,
          name: checkpoint.name,
          completed: true,
          photoUrl: checkpoint.photoUrl,
          reason: reasonController.text.trim(),
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _gettingLocationFor = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Checkpoint berhasil diselesaikan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _gettingLocationFor = null;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mendapatkan GPS: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _uploadCheckpointPhoto(int index) async {
    final checkpoint = _checkpoints[index];
    
    // Buka kamera untuk foto checkpoint
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          title: 'Foto untuk ${checkpoint.name}',
        ),
      ),
    );

    if (photo != null && mounted) {
      final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
      
      // Upload foto checkpoint
      final uploadResult = await activityProvider.uploadCheckpointPhoto(
        photo: photo,
        checkpointId: checkpoint.id,
      );

      if (uploadResult['success'] == true) {
        setState(() {
          _checkpoints[index] = SecurityCheckpoint(
            id: checkpoint.id,
            name: checkpoint.name,
            completed: checkpoint.completed,
            photoUrl: uploadResult['data']['photoUrl'],
            reason: checkpoint.reason,
            latitude: checkpoint.latitude,
            longitude: checkpoint.longitude,
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto checkpoint berhasil diunggah'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(uploadResult['message'] ?? 'Gagal mengunggah foto'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _submitPatroli() async {
    if (_summaryController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Summary wajib diisi')),
      );
      return;
    }

    final allCompleted = _checkpoints.every((cp) => cp.completed);
    if (!allCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua checkpoint harus diselesaikan')),
      );
      return;
    }

    // Validasi semua checkpoint punya foto dan reason
    for (var cp in _checkpoints) {
      if (cp.photoUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkpoint ${cp.name} belum memiliki foto')),
        );
        return;
      }
      if (cp.reason == null || cp.reason!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Checkpoint ${cp.name} belum memiliki alasan/findings')),
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
    final success = await activityProvider.submitPatroli(
      summary: _summaryController.text.trim(),
      checkpoints: _checkpoints,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Laporan patroli berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        // Reset form
        _summaryController.clear();
        _notesController.clear();
        _checkpoints = List.from(_defaultCheckpoints);
        for (var controller in _reasonControllers.values) {
          controller.clear();
        }
        await activityProvider.loadActivities();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(activityProvider.error ?? 'Gagal menyimpan laporan patroli'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patroli Security'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary
            TextField(
              controller: _summaryController,
              decoration: const InputDecoration(
                labelText: 'Summary *',
                hintText: 'Ringkasan patroli hari ini',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            // Notes
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            // Checkpoints
            Text(
              'Checkpoints',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            ..._checkpoints.asMap().entries.map((entry) {
              final index = entry.key;
              final checkpoint = entry.value;
              final reasonController = _reasonControllers[checkpoint.id];
              final isGettingLocation = _gettingLocationFor == checkpoint.id;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: checkpoint.completed ? Colors.green[50] : null,
                child: ExpansionTile(
                  leading: checkpoint.completed
                      ? Icon(Icons.check_circle, color: Colors.green[700])
                      : const Icon(Icons.radio_button_unchecked),
                  title: Text(
                    checkpoint.name,
                    style: TextStyle(
                      fontWeight: checkpoint.completed ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: checkpoint.completed
                      ? Text(
                          'Selesai: ${checkpoint.photoUrl != null ? "Foto ✓" : ""} ${checkpoint.reason != null ? "| Alasan ✓" : ""}',
                          style: TextStyle(color: Colors.green[700], fontSize: 12),
                        )
                      : null,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Foto Section
                          if (checkpoint.photoUrl != null) ...[
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  ApiConfig.getImageUrl(checkpoint.photoUrl!),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress.expectedTotalBytes != null
                                            ? loadingProgress.cumulativeBytesLoaded /
                                                loadingProgress.expectedTotalBytes!
                                            : null,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // Upload Foto Button
                          ElevatedButton.icon(
                            onPressed: checkpoint.photoUrl != null
                                ? null
                                : () => _uploadCheckpointPhoto(index),
                            icon: Icon(checkpoint.photoUrl != null ? Icons.check : Icons.camera_alt),
                            label: Text(checkpoint.photoUrl != null ? 'Foto Sudah Diunggah' : 'Ambil Foto'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: checkpoint.photoUrl != null ? Colors.grey : Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Reason/Findings Input
                          TextField(
                            controller: reasonController,
                            decoration: InputDecoration(
                              labelText: 'Alasan/Findings *',
                              hintText: 'Masukkan alasan atau temuan untuk checkpoint ini',
                              border: const OutlineInputBorder(),
                              suffixIcon: checkpoint.reason != null && checkpoint.reason!.isNotEmpty
                                  ? Icon(Icons.check, color: Colors.green[700])
                                  : null,
                            ),
                            maxLines: 3,
                            enabled: checkpoint.photoUrl != null,
                          ),
                          const SizedBox(height: 16),
                          // Complete Button
                          if (checkpoint.photoUrl != null && 
                              reasonController != null && 
                              reasonController.text.trim().isNotEmpty &&
                              !checkpoint.completed) ...[
                            ElevatedButton.icon(
                              onPressed: isGettingLocation ? null : () => _completeCheckpoint(index),
                              icon: isGettingLocation
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.check_circle),
                              label: Text(isGettingLocation ? 'Mengambil GPS...' : 'Selesaikan Checkpoint'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                          // GPS Info
                          if (checkpoint.completed && checkpoint.latitude != null && checkpoint.longitude != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, size: 16, color: Colors.blue[700]),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'GPS: ${checkpoint.latitude!.toStringAsFixed(6)}, ${checkpoint.longitude!.toStringAsFixed(6)}',
                                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),
            // Progress Indicator
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    'Progress: ${_checkpoints.where((cp) => cp.completed).length} / ${_checkpoints.length} checkpoint',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[900],
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _checkpoints.where((cp) => cp.completed).length / _checkpoints.length,
                    backgroundColor: Colors.blue[200],
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[700]!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Submit Button
            Consumer<ActivityProvider>(
              builder: (context, activityProvider, _) {
                return ElevatedButton(
                  onPressed: (_isSubmitting || activityProvider.isLoading)
                      ? null
                      : _submitPatroli,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: (_isSubmitting || activityProvider.isLoading)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Laporan Patroli',
                          style: TextStyle(fontSize: 16),
                        ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
