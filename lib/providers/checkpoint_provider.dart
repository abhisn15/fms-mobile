import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/checkpoint_model.dart';
import '../services/checkpoint_service.dart';

class CheckpointTodoPreview {
  final String templateId;
  final String templateName;
  final int completedCount;
  final int totalCount;
  final List<CheckpointProgressItem> pendingItems;

  const CheckpointTodoPreview({
    required this.templateId,
    required this.templateName,
    required this.completedCount,
    required this.totalCount,
    required this.pendingItems,
  });
}

/// Provider untuk menyimpan state checkpoint.
/// Pre-fetch di home, dipakai di activity form tanpa loading ulang.
class CheckpointProvider extends ChangeNotifier {
  final CheckpointService _service = CheckpointService();

  EssCheckpointPayload? _payload;
  String? _activeTemplateId;
  bool _loading = false;
  String? _error;
  DateTime? _lastFetched;
  bool _hasFetchedOnce = false;

  EssCheckpointPayload? get payload => _payload;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasFetchedOnce => _hasFetchedOnce;
  bool get hasCheckpoint => _payload?.hasCheckpoint ?? false;
  List<EssCheckpointTemplateState> get templateStates =>
      _payload?.templates ?? const [];
  bool get hasMultipleTemplates => templateStates.length > 1;
  String? get activeTemplateId => _activeTemplateId;

  EssCheckpointTemplateState? get activeTemplateState {
    if (templateStates.isEmpty) return null;
    if (_activeTemplateId == null) return templateStates.first;
    return templateStates.firstWhere(
      (entry) => entry.template.id == _activeTemplateId,
      orElse: () => templateStates.first,
    );
  }

  CheckpointTemplate? get template =>
      activeTemplateState?.template ?? _payload?.template;
  List<CheckpointProgressItem> get progress =>
      activeTemplateState?.progress ?? _payload?.progress ?? const [];
  int get completedCount => _payload?.completedCount ?? 0;
  int get totalCount => _payload?.totalCount ?? 0;
  double get percentage => totalCount > 0 ? completedCount / totalCount : 0;

  List<CheckpointTodoPreview> get todoPreviews {
    if (templateStates.isEmpty) return const [];
    return templateStates.map((state) {
      final pending = state.progress.where((item) => !item.completed).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      return CheckpointTodoPreview(
        templateId: state.template.id,
        templateName: state.template.name,
        completedCount: state.completedCount,
        totalCount: state.totalCount,
        pendingItems: pending,
      );
    }).toList();
  }

  /// Nama tugas berikutnya yang belum selesai
  String? get nextTaskName {
    if (templateStates.isEmpty) {
      if (_payload?.progress == null || _payload?.template == null) return null;
      final sorted = [..._payload!.progress!]
        ..sort((a, b) => a.order.compareTo(b.order));
      if (_payload!.template!.isMandatoryOrder) {
        final next = sorted.firstWhere(
          (p) => !p.completed,
          orElse: () => sorted.last,
        );
        return next.completed ? null : next.name;
      }
      final pending = sorted.where((p) => !p.completed).toList();
      return pending.isNotEmpty ? pending.first.name : null;
    }

    for (final state in templateStates) {
      final sorted = [...state.progress]
        ..sort((a, b) => a.order.compareTo(b.order));
      final pending = sorted.where((p) => !p.completed).toList();
      if (pending.isEmpty) continue;
      final label = pending.first.name;
      return hasMultipleTemplates ? '${state.template.name}: $label' : label;
    }
    return null;
  }

  void setActiveTemplate(String templateId) {
    if (templateStates.isEmpty) return;
    final exists = templateStates.any(
      (entry) => entry.template.id == templateId,
    );
    if (!exists || _activeTemplateId == templateId) return;
    _activeTemplateId = templateId;
    notifyListeners();
  }

  void _ensureActiveTemplate() {
    if (templateStates.isEmpty) {
      _activeTemplateId = null;
      return;
    }
    if (_activeTemplateId != null &&
        templateStates.any((entry) => entry.template.id == _activeTemplateId)) {
      return;
    }
    _activeTemplateId = templateStates.first.template.id;
  }

  /// Load checkpoint dari server. Jika sudah di-load dalam 30 detik terakhir, skip.
  Future<void> loadCheckpoint({bool force = false}) async {
    if (_loading) return;
    if (!force && _lastFetched != null) {
      final diff = DateTime.now().difference(_lastFetched!).inSeconds;
      if (diff < 30) return; // Skip jika baru fetch < 30 detik lalu
    }

    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _payload = await _service.getActiveCheckpoint();
      _ensureActiveTemplate();
      _lastFetched = DateTime.now();
      debugPrint(
        '[CheckpointProvider] Loaded: hasCheckpoint=${_payload?.hasCheckpoint}, templates=${templateStates.length}, active=${activeTemplateState?.template.name}',
      );
    } catch (e) {
      _error = e.toString();
      debugPrint('[CheckpointProvider] Error: $e');
    } finally {
      _loading = false;
      _hasFetchedOnce = true;
      notifyListeners();
    }
  }

  void clear() {
    _payload = null;
    _activeTemplateId = null;
    _loading = false;
    _error = null;
    _lastFetched = null;
    _hasFetchedOnce = false;
    notifyListeners();
  }

  /// Update progress setelah complete satu item
  void updateProgress(
    List<CheckpointProgressItem> newProgress, {
    String? templateId,
  }) {
    if (_payload != null) {
      final targetTemplateId = templateId ?? activeTemplateState?.template.id;
      final currentTemplates = [...templateStates];
      if (targetTemplateId != null && currentTemplates.isNotEmpty) {
        final targetIndex = currentTemplates.indexWhere(
          (entry) => entry.template.id == targetTemplateId,
        );
        if (targetIndex >= 0) {
          final current = currentTemplates[targetIndex];
          currentTemplates[targetIndex] = current.copyWith(
            progress: newProgress,
          );
        }
      }

      final nextPrimary = currentTemplates.isNotEmpty
          ? currentTemplates.firstWhere(
              (entry) =>
                  entry.template.id ==
                  (_activeTemplateId ?? currentTemplates.first.template.id),
              orElse: () => currentTemplates.first,
            )
          : null;

      _payload = EssCheckpointPayload(
        hasCheckpoint: _payload!.hasCheckpoint,
        template: nextPrimary?.template ?? _payload!.template,
        assignmentId: nextPrimary?.assignmentId ?? _payload!.assignmentId,
        progress: nextPrimary?.progress ?? _payload!.progress,
        activityId: nextPrimary?.activityId ?? _payload!.activityId,
        templates: currentTemplates,
        totalTemplates: currentTemplates.length,
      );
      _ensureActiveTemplate();
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
    String? templateId,
  }) async {
    try {
      final targetTemplateId = templateId ?? activeTemplateState?.template.id;
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
        templateId: targetTemplateId,
      );

      if (result['success'] == true && result['data'] != null) {
        final data = result['data'];
        if (data['progress'] is List) {
          final newProgress = (data['progress'] as List)
              .whereType<Map<String, dynamic>>()
              .map((e) => CheckpointProgressItem.fromJson(e))
              .toList();
          updateProgress(newProgress, templateId: targetTemplateId);
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
