import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/checkpoint_model.dart';
import '../services/checkpoint_service.dart';

/// Provider untuk menyimpan state checkpoint.
/// Pre-fetch di home, dipakai di activity form tanpa loading ulang.
class CheckpointProvider extends ChangeNotifier {
  final CheckpointService _service = CheckpointService();

  EssCheckpointPayload? _payload;
  bool _loading = false;
  String? _error;
  DateTime? _lastFetched;

  EssCheckpointPayload? get payload => _payload;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasCheckpoint => _payload?.hasCheckpoint ?? false;
  CheckpointTemplate? get template => _payload?.template;
  List<CheckpointProgressItem> get progress => _payload?.progress ?? [];
  int get completedCount => _payload?.completedCount ?? 0;
  int get totalCount => _payload?.totalCount ?? 0;
  double get percentage => _payload?.percentage ?? 0;

  /// Nama tugas berikutnya yang belum selesai
  String? get nextTaskName {
    if (_payload?.progress == null || _payload?.template == null) return null;
    final sorted = [..._payload!.progress!]..sort((a, b) => a.order.compareTo(b.order));
    
    if (_payload!.template!.isMandatoryOrder) {
      // Mandatory: cari yang pertama belum selesai
      final next = sorted.firstWhere((p) => !p.completed, orElse: () => sorted.last);
      return next.completed ? null : next.name;
    } else {
      // Bebas: cari yang pertama belum selesai (urutan)
      final pending = sorted.where((p) => !p.completed).toList();
      return pending.isNotEmpty ? pending.first.name : null;
    }
  }

  /// Load checkpoint dari server. Jika sudah di-load dalam 30 detik terakhir, skip.
  Future<void> loadCheckpoint({bool force = false}) async {
    if (!force && _lastFetched != null) {
      final diff = DateTime.now().difference(_lastFetched!).inSeconds;
      if (diff < 30) return; // Skip jika baru fetch < 30 detik lalu
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _payload = await _service.getActiveCheckpoint();
      _lastFetched = DateTime.now();
      debugPrint('[CheckpointProvider] Loaded: hasCheckpoint=${_payload?.hasCheckpoint}, progress=${_payload?.progress?.length}');
    } catch (e) {
      _error = e.toString();
      debugPrint('[CheckpointProvider] Error: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Update progress setelah complete satu item
  void updateProgress(List<CheckpointProgressItem> newProgress) {
    if (_payload != null) {
      _payload = EssCheckpointPayload(
        hasCheckpoint: _payload!.hasCheckpoint,
        template: _payload!.template,
        assignmentId: _payload!.assignmentId,
        progress: newProgress,
        activityId: _payload!.activityId,
      );
      notifyListeners();
    }
  }

  /// Complete satu checkpoint item via API.
  /// Mendukung single (photoBefore/photoAfter) atau multiple (photosBefore/photosAfter).
  Future<bool> completeItem(
    String itemId, {
    File? photoBefore,
    File? photoAfter,
    List<File>? photosBefore,
    List<File>? photosAfter,
    String? notes,
    double? latitude,
    double? longitude,
    double? accuracy,
  }) async {
    try {
      final result = await _service.completeCheckpoint(
        itemId: itemId,
        photoBefore: photoBefore,
        photoAfter: photoAfter,
        photosBefore: photosBefore,
        photosAfter: photosAfter,
        notes: notes,
        latitude: latitude,
        longitude: longitude,
        accuracy: accuracy,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        if (data['progress'] is List) {
          final newProgress = (data['progress'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => CheckpointProgressItem.fromJson(e))
              .toList();
          updateProgress(newProgress);
        }
        return true;
      }
      _error = result['message'] ?? 'Gagal menyelesaikan checkpoint';
      notifyListeners();
      return false;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
