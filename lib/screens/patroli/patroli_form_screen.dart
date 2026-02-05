import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/activity_provider.dart';
import '../../screens/camera/camera_screen.dart';
import '../../utils/toast_helper.dart';
import 'dart:io';

class PatroliFormScreen extends StatefulWidget {
  const PatroliFormScreen({super.key});

  @override
  State<PatroliFormScreen> createState() => _PatroliFormScreenState();
}

class _PatroliFormScreenState extends State<PatroliFormScreen> {
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  List<File> _photos = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Add listeners to update UI when text changes
    _locationController.addListener(() {
      setState(() {});
    });
    _descriptionController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Check if form is valid (all required fields filled)
  bool get _isFormValid {
    return _locationController.text.trim().isNotEmpty && _photos.isNotEmpty;
  }

  Future<void> _takePhoto() async {
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => const CameraScreen(
          title: 'Foto Patroli',
          allowGallery: false, // Hanya kamera untuk patroli
          preferLowResolution: true,
        ),
      ),
    );

    if (photo != null && mounted) {
      setState(() {
        _photos.add(photo);
      });
    }
  }

  void _removePhoto(int index) {
    setState(() {
      _photos.removeAt(index);
    });
  }

  Future<void> _submitPatroli() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ToastHelper.showWarning(context, 'Tempat patroli wajib diisi');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final activityProvider = Provider.of<ActivityProvider>(context, listen: false);
    
    // Format notes untuk backend: "📍 [Location]\n\n[Description]"
    // Backend akan extract locationName dari notes jika ada format ini
    final notes = _descriptionController.text.trim().isNotEmpty
        ? '📍 ${_locationController.text.trim()}\n\n${_descriptionController.text.trim()}'
        : '📍 ${_locationController.text.trim()}';

    final success = await activityProvider.submitPatroli(
      summary: _locationController.text.trim(), // Summary = Location name
      notes: notes, // Notes dengan format "📍 [Location]\n\n[Description]"
      photos: _photos,
    );

    if (mounted) {
      setState(() {
        _isSubmitting = false;
      });

      if (success) {
        final successMessage = activityProvider.successMessage;
        ToastHelper.showSuccess(
          context,
          successMessage ?? 'Laporan patroli berhasil disimpan',
        );
        Navigator.pop(context);
      } else {
        ToastHelper.showError(
          context,
          activityProvider.error ?? 'Gagal menyimpan laporan patroli',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Laporan Patroli'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Location Field
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Tempat Patroli *',
                  hintText: 'Contoh: Gerbang Utama, Area Parkir, dll',
                  prefixIcon: const Icon(Icons.location_on),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                  helperText: 'Masukkan lokasi atau tempat patroli',
                  helperMaxLines: 2,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tempat patroli wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Description Field
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Deskripsi',
                  hintText: 'Deskripsikan kondisi atau temuan di lokasi patroli',
                  prefixIcon: const Icon(Icons.description),
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[50],
                  helperText: 'Jelaskan apa yang ditemukan atau kondisi di lokasi (opsional)',
                  helperMaxLines: 2,
                ),
                maxLines: 5,
                minLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 20),

              // Photos Section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.camera_alt, color: Colors.blue[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Foto Patroli',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ambil foto menggunakan kamera untuk dokumentasi patroli *',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Photo List
                    if (_photos.isNotEmpty) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: _photos.asMap().entries.map((entry) {
                          final index = entry.key;
                          final photo = entry.value;
                          return Stack(
                            children: [
                              Container(
                                width: 100,
                                height: 133, // 100 * 4/3 untuk portrait (lebih tinggi)
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[300]!, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Image.file(
                                    photo,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: -4,
                                right: -4,
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
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Add Photo Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.camera_alt, size: 20),
                        label: Text(_photos.isEmpty ? 'Ambil Foto' : 'Tambah Foto Lagi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              Consumer<ActivityProvider>(
                builder: (context, activityProvider, _) {
                  final isEnabled = _isFormValid && !_isSubmitting && !activityProvider.isLoading;
                  
                  return ElevatedButton(
                    onPressed: isEnabled ? _submitPatroli : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: isEnabled ? Colors.blue[700] : Colors.grey[400],
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[400],
                      disabledForegroundColor: Colors.grey[600],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isEnabled ? 2 : 0,
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
                        : Text(
                            'Submit Laporan Patroli',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isEnabled ? Colors.white : Colors.grey[600],
                            ),
                          ),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

