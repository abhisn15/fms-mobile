import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../screens/camera/camera_screen.dart';
import 'package:intl/intl.dart';
import '../models/checkpoint_model.dart';
import '../config/api_config.dart';

class CheckpointTimelineWidget extends StatefulWidget {
  final CheckpointTemplate template;
  final List<CheckpointProgressItem> progress;
  final Future<void> Function(
    String itemId, {
    File? photoBefore,
    File? photoAfter,
    List<File>? photosBefore,
    List<File>? photosAfter,
    String? notes,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) onComplete;
  final bool isSubmitting;

  const CheckpointTimelineWidget({
    super.key,
    required this.template,
    required this.progress,
    required this.onComplete,
    this.isSubmitting = false,
  });

  @override
  State<CheckpointTimelineWidget> createState() => _CheckpointTimelineWidgetState();
}

class _CheckpointTimelineWidgetState extends State<CheckpointTimelineWidget> {
  String? _expandedItemId;

  int get completedCount => widget.progress.where((p) => p.completed).length;
  int get totalCount => widget.progress.length;
  double get percentage => totalCount > 0 ? completedCount / totalCount : 0;

  int get _nextPendingOrder {
    if (!widget.template.isMandatoryOrder) return -1;
    final sorted = [...widget.template.items]..sort((a, b) => a.order.compareTo(b.order));
    for (final item in sorted) {
      final p = widget.progress.firstWhere((pr) => pr.id == item.id,
          orElse: () => CheckpointProgressItem(id: item.id, name: item.name, order: item.order, completed: false));
      if (!p.completed) return item.order;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final sortedItems = [...widget.template.items]..sort((a, b) => a.order.compareTo(b.order));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + Progress — kartu ringkasan dipercantik
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue.shade400, Colors.blue.shade600],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.shade200.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.flag_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Misi / Checkpoint',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$completedCount/$totalCount',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: percentage,
                  minHeight: 8,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                widget.template.name,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.95),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (widget.template.isMandatoryOrder) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 14, color: Colors.amber.shade200),
                    const SizedBox(width: 4),
                    Text(
                      'Wajib berurutan',
                      style: TextStyle(fontSize: 11, color: Colors.amber.shade100, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Items
        ...sortedItems.map((item) {
          final itemProgress = widget.progress.firstWhere((p) => p.id == item.id,
              orElse: () => CheckpointProgressItem(id: item.id, name: item.name, order: item.order, completed: false));
          final isCompleted = itemProgress.completed;
          final isLocked = widget.template.isMandatoryOrder && item.order > _nextPendingOrder && !isCompleted;

          return _CheckpointCard(
            item: item,
            progress: itemProgress,
            isCompleted: isCompleted,
            isLocked: isLocked,
            isExpanded: _expandedItemId == item.id,
            onTap: () {
              if (!isCompleted && !isLocked) setState(() => _expandedItemId = _expandedItemId == item.id ? null : item.id);
            },
            onComplete: widget.onComplete,
            isSubmitting: widget.isSubmitting,
          );
        }),
      ],
    );
  }
}

class _CheckpointCard extends StatefulWidget {
  final CheckpointTemplateItem item;
  final CheckpointProgressItem progress;
  final bool isCompleted;
  final bool isLocked;
  final bool isExpanded;
  final VoidCallback onTap;
  final Future<void> Function(String itemId, {File? photoBefore, File? photoAfter, List<File>? photosBefore, List<File>? photosAfter, String? notes, double? latitude, double? longitude, double? accuracy}) onComplete;
  final bool isSubmitting;

  const _CheckpointCard({
    required this.item, required this.progress, required this.isCompleted, required this.isLocked,
    required this.isExpanded, required this.onTap, required this.onComplete, required this.isSubmitting,
  });

  @override
  State<_CheckpointCard> createState() => _CheckpointCardState();
}

class _CheckpointCardState extends State<_CheckpointCard> {
  File? _photoBefore;
  File? _photoAfter;
  final List<File> _photoBefores = [];
  final List<File> _photoAfters = [];
  final _notesController = TextEditingController();
  bool _completing = false;
  Position? _gpsPosition;

  bool get _allowMultiple => widget.item.allowMultiplePhotos;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _takePhoto(bool isBefore) async {
    final title = isBefore ? 'Foto Before' : 'Foto After';
    final photo = await Navigator.push<File>(
      context,
      MaterialPageRoute(
        builder: (_) => CameraScreen(
          title: title,
          allowGallery: true,
          preferLowResolution: false,
        ),
      ),
    );
    if (photo != null && mounted) {
      setState(() {
        if (_allowMultiple) {
          if (isBefore) {
            _photoBefores.add(photo);
          } else {
            _photoAfters.add(photo);
          }
        } else {
          if (isBefore) {
            _photoBefore = photo;
          } else {
            _photoAfter = photo;
          }
        }
      });
    }
  }

  void _showFullScreenImage(File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(file, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Position?> _getGPS() async {
    if (_gpsPosition != null) return _gpsPosition;
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aktifkan GPS/Lokasi terlebih dahulu')));
        return null;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Izin lokasi ditolak permanen')));
        return null;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(
        const Duration(seconds: 15),
        onTimeout: () => Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.medium),
      );
      setState(() => _gpsPosition = pos);
      return pos;
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
      return null;
    }
  }

  Future<void> _handleComplete() async {
    if (widget.item.requiresPhoto) {
      if (_allowMultiple) {
        if (_photoBefores.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal 1 foto BEFORE wajib diambil')));
          return;
        }
        if (_photoAfters.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal 1 foto AFTER wajib diambil')));
          return;
        }
      } else {
        if (_photoBefore == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto BEFORE wajib diambil')));
          return;
        }
        if (_photoAfter == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Foto AFTER wajib diambil')));
          return;
        }
      }
    }

    setState(() => _completing = true);
    try {
      final pos = await _getGPS();
      await widget.onComplete(
        widget.item.id,
        photoBefore: _allowMultiple ? null : _photoBefore,
        photoAfter: _allowMultiple ? null : _photoAfter,
        photosBefore: _allowMultiple && _photoBefores.isNotEmpty ? List.from(_photoBefores) : null,
        photosAfter: _allowMultiple && _photoAfters.isNotEmpty ? List.from(_photoAfters) : null,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        latitude: pos?.latitude,
        longitude: pos?.longitude,
        accuracy: pos?.accuracy,
      );
      if (mounted) {
        setState(() {
          _photoBefore = null;
          _photoAfter = null;
          _photoBefores.clear();
          _photoAfters.clear();
          _notesController.clear();
          _gpsPosition = null;
        });
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isCompleted) return _buildCompleted();
    if (widget.isLocked) return _buildLocked();
    return _buildPending();
  }

  Widget _buildCompleted() {
    final time = widget.progress.timestamp != null
        ? DateFormat('HH:mm').format(DateTime.parse(widget.progress.timestamp!).toLocal())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.shade200),
        boxShadow: [
          BoxShadow(color: Colors.green.shade100.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.item.name,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.green.shade800),
                ),
              ),
              if (time != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(time, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
                ),
            ],
          ),
          if (widget.progress.notes != null && widget.progress.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 38),
              child: Text(
                widget.progress.notes!,
                style: TextStyle(fontSize: 12, color: Colors.green.shade700, height: 1.4),
              ),
            ),
          if (widget.progress.latitude != null && widget.progress.longitude != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 38),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, size: 14, color: Colors.green.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.progress.latitude!.toStringAsFixed(5)}, ${widget.progress.longitude!.toStringAsFixed(5)}${widget.progress.accuracy != null ? ' (${widget.progress.accuracy!.round()}m)' : ''}',
                    style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                  ),
                ],
              ),
            ),
          if (widget.progress.beforePhotoUrls.isNotEmpty || widget.progress.afterPhotoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 38),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (widget.progress.beforePhotoUrls.isNotEmpty)
                    ...widget.progress.beforePhotoUrls.asMap().entries.map(
                      (e) => _photoThumb('Before${widget.progress.beforePhotoUrls.length > 1 ? " ${e.key + 1}" : ""}', e.value),
                    ),
                  if (widget.progress.afterPhotoUrls.isNotEmpty)
                    ...widget.progress.afterPhotoUrls.asMap().entries.map(
                      (e) => _photoThumb('After${widget.progress.afterPhotoUrls.length > 1 ? " ${e.key + 1}" : ""}', e.value),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoThumb(String label, String url) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.green.shade700)),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.network(
            ApiConfig.getImageUrl(url),
            height: 56,
            width: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 56,
              height: 56,
              color: Colors.grey.shade200,
              child: Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey.shade500),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocked() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.lock_rounded, color: Colors.grey.shade500, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item.name,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Selesaikan tugas sebelumnya terlebih dahulu',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPending() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.blue.shade400, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Colors.grey.shade800,
                            ),
                          ),
                          if (widget.item.description != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.item.description!,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                          if (widget.item.requiresPhoto) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.camera_alt_rounded, size: 13, color: Colors.orange.shade600),
                                const SizedBox(width: 4),
                                Text(
                                  widget.item.allowMultiplePhotos
                                      ? 'Foto before & after wajib (bisa banyak)'
                                      : 'Foto before & after wajib',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.orange.shade600),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      widget.isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.grey.shade500,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (widget.isExpanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              color: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 14),

                  if (_allowMultiple)
                    _photoSectionMultiple('Foto Sebelum (Before)', _photoBefores, true, widget.item.requiresPhoto),
                  if (!_allowMultiple)
                    _photoSection('Foto Sebelum (Before)', _photoBefore, true, widget.item.requiresPhoto),
                  const SizedBox(height: 14),

                  if (_allowMultiple)
                    _photoSectionMultiple('Foto Sesudah (After)', _photoAfters, false, widget.item.requiresPhoto),
                  if (!_allowMultiple)
                    _photoSection('Foto Sesudah (After)', _photoAfter, false, widget.item.requiresPhoto),
                  const SizedBox(height: 14),

                  Text(
                    'Deskripsi / Catatan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Jelaskan apa yang dikerjakan...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.blue.shade400, width: 1.5),
                      ),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  if (_gpsPosition != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 16, color: Colors.blue.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${_gpsPosition!.latitude.toStringAsFixed(5)}, ${_gpsPosition!.longitude.toStringAsFixed(5)} (${_gpsPosition!.accuracy.round()}m)',
                              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
                            ),
                          ),
                        ],
                      ),
                    ),

                  ElevatedButton.icon(
                    onPressed: (_completing || widget.isSubmitting) ? null : _handleComplete,
                    icon: _completing
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Icon(Icons.check_circle_rounded, size: 20),
                    label: Text(
                      _completing ? 'Menyimpan...' : 'Selesaikan Tugas',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _photoSection(String label, File? file, bool isBefore, bool required) {
    final accentColor = isBefore ? Colors.blue : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            if (required) Text(' *', style: TextStyle(fontSize: 12, color: Colors.red.shade500, fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        if (file != null)
          Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: () => _showFullScreenImage(file),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(file, height: 120, width: double.infinity, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() { if (isBefore) _photoBefore = null; else _photoAfter = null; }),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ]),
                    child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ),
            ],
          )
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _takePhoto(isBefore),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: accentColor.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.camera_alt_rounded, size: 22, color: accentColor.shade600),
                    const SizedBox(width: 10),
                    Text(
                      isBefore ? 'Ambil Foto Before' : 'Ambil Foto After',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _photoSectionMultiple(String label, List<File> files, bool isBefore, bool required) {
    final accentColor = isBefore ? Colors.blue : Colors.green;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            ),
            if (required) Text(' *', style: TextStyle(fontSize: 12, color: Colors.red.shade500, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Text(
              '(${files.length} foto)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (files.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in files.asMap().entries) ...[
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: () => _showFullScreenImage(entry.value),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(entry.value, height: 80, width: 80, fit: BoxFit.cover),
                      ),
                    ),
                    Positioned(
                      top: -4,
                      right: -4,
                      child: GestureDetector(
                        onTap: () {
                          final idx = entry.key;
                          setState(() {
                            if (isBefore) _photoBefores.removeAt(idx);
                            else _photoAfters.removeAt(idx);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _takePhoto(isBefore),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: accentColor.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: accentColor.shade200),
                    ),
                    child: Icon(Icons.add_photo_alternate_rounded, size: 28, color: accentColor.shade600),
                  ),
                ),
              ),
            ],
          )
        else
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _takePhoto(isBefore),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: accentColor.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: accentColor.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate_rounded, size: 22, color: accentColor.shade600),
                    const SizedBox(width: 10),
                    Text(
                      isBefore ? 'Tambah Foto Before' : 'Tambah Foto After',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accentColor.shade700),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
