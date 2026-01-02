import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../providers/request_provider.dart';
import '../../widgets/adaptive_image.dart' as adaptive_image;

class RequestFormScreen extends StatefulWidget {
  const RequestFormScreen({super.key});

  @override
  State<RequestFormScreen> createState() => _RequestFormScreenState();
}

class _RequestFormScreenState extends State<RequestFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String _selectedType = 'izin';
  DateTime? _startDate;
  DateTime? _endDate;
  final List<File> _photos = [];
  final ImagePicker _imagePicker = ImagePicker();

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(_startDate!)) {
          _endDate = null;
        }
      });
    }
  }

  Future<void> _selectEndDate() async {
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai terlebih dahulu')),
      );
      return;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _photos.add(File(pickedFile.path));
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengambil foto: $e')),
        );
      }
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal mulai dan tanggal akhir')),
      );
      return;
    }

    final requestProvider = Provider.of<RequestProvider>(context, listen: false);
    final success = await requestProvider.createRequest(
      type: _selectedType,
      reason: _reasonController.text.trim(),
      startDate: DateFormat('yyyy-MM-dd').format(_startDate!),
      endDate: DateFormat('yyyy-MM-dd').format(_endDate!),
      photos: _photos,
    );

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request berhasil dikirim'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(requestProvider.error ?? 'Gagal mengirim request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buat Request'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Type
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(
                labelText: 'Jenis Request *',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'izin', child: Text('Izin')),
                DropdownMenuItem(value: 'cuti', child: Text('Cuti')),
                DropdownMenuItem(value: 'sakit', child: Text('Sakit')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            // Start Date
            InkWell(
              onTap: _selectStartDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Mulai *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _startDate == null
                      ? 'Pilih tanggal'
                      : DateFormat('dd MMMM yyyy').format(_startDate!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // End Date
            InkWell(
              onTap: _selectEndDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal Akhir *',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(
                  _endDate == null
                      ? 'Pilih tanggal'
                      : DateFormat('dd MMMM yyyy').format(_endDate!),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Reason
            TextFormField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Alasan *',
                hintText: 'Masukkan alasan request',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Alasan wajib diisi';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Photos (especially useful for sick leave)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Foto Bukti',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(Opsional - sangat berguna untuk izin sakit)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_photos.isNotEmpty) ...[
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: adaptive_image.AdaptiveImage.file(
                                  _photos[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 12,
                              child: GestureDetector(
                                onTap: () => _removePhoto(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton.icon(
                  onPressed: _photos.length >= 5 ? null : _pickPhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_photos.isEmpty ? 'Ambil Foto' : 'Tambah Foto (${_photos.length}/5)'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                if (_photos.length >= 5) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Maksimal 5 foto',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.orange[700],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),
            // Submit Button
            Consumer<RequestProvider>(
              builder: (context, requestProvider, _) {
                return ElevatedButton(
                  onPressed: requestProvider.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: requestProvider.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Kirim Request',
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

