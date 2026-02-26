import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../../models/payroll_slip_model.dart';
import '../../services/payroll_slip_service.dart';

class PayrollSlipsScreen extends StatefulWidget {
  const PayrollSlipsScreen({super.key});

  @override
  State<PayrollSlipsScreen> createState() => _PayrollSlipsScreenState();
}

class _PayrollSlipsScreenState extends State<PayrollSlipsScreen> {
  final PayrollSlipService _payrollSlipService = PayrollSlipService();
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _createdAtFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  bool _isLoading = true;
  String? _error;
  List<PayrollSlip> _allSlips = [];
  List<PayrollSlip> _filteredSlips = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applySearchFilter);
    _loadPayrollSlips();
  }

  @override
  void dispose() {
    _searchController.removeListener(_applySearchFilter);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPayrollSlips() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final items = await _payrollSlipService.getPayrollSlips();
      if (!mounted) return;
      setState(() {
        _allSlips = items;
        _filteredSlips = items;
      });
      _applySearchFilter();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applySearchFilter() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      if (!mounted) return;
      setState(() {
        _filteredSlips = List<PayrollSlip>.from(_allSlips);
      });
      return;
    }

    final filtered = _allSlips.where((slip) {
      final period = slip.displayPeriod.toLowerCase();
      final fileName = slip.fileName.toLowerCase();
      final periodKey = slip.periodKey.toLowerCase();
      return period.contains(query) ||
          fileName.contains(query) ||
          periodKey.contains(query);
    }).toList();

    if (!mounted) return;
    setState(() {
      _filteredSlips = filtered;
    });
  }

  String _formatFileSize(int bytes) {
    if (bytes <= 0) return '-';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatCreatedAt(DateTime? value) {
    if (value == null) return '-';
    return _createdAtFormat.format(value.toLocal());
  }

  Future<void> _openSlip(PayrollSlip slip) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _PayrollSlipPdfViewerScreen(
          slip: slip,
          payrollSlipService: _payrollSlipService,
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
                color: Colors.redAccent,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _loadPayrollSlips,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_allSlips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Belum ada slip gaji.', textAlign: TextAlign.center),
        ),
      );
    }

    if (_filteredSlips.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Data tidak ditemukan. Ubah kata kunci pencarian.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayrollSlips,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _filteredSlips.length,
        itemBuilder: (context, index) {
          final slip = _filteredSlips[index];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.receipt_long_outlined),
              ),
              title: Text(
                slip.displayPeriod,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Versi ${slip.version}'),
                  Text('Ukuran: ${_formatFileSize(slip.fileSize)}'),
                  Text('Dibuat: ${_formatCreatedAt(slip.createdAt)}'),
                ],
              ),
              trailing: IconButton(
                tooltip: 'Lihat Slip',
                icon: const Icon(Icons.visibility_outlined),
                onPressed: () => _openSlip(slip),
              ),
              onTap: () => _openSlip(slip),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Slip Gaji'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadPayrollSlips,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Cari periode atau nama file...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _applySearchFilter();
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}

class _PayrollSlipPdfViewerScreen extends StatefulWidget {
  final PayrollSlip slip;
  final PayrollSlipService payrollSlipService;

  const _PayrollSlipPdfViewerScreen({
    required this.slip,
    required this.payrollSlipService,
  });

  @override
  State<_PayrollSlipPdfViewerScreen> createState() =>
      _PayrollSlipPdfViewerScreenState();
}

class _PayrollSlipPdfViewerScreenState
    extends State<_PayrollSlipPdfViewerScreen> {
  Uint8List? _pdfBytes;
  String? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bytes = await widget.payrollSlipService.getPayrollSlipPdfBytes(
        widget.slip,
      );
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Slip ${widget.slip.displayPeriod}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadPdf,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadPdf,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            )
          : _pdfBytes == null
          ? const Center(child: Text('File slip gaji tidak tersedia.'))
          : SfPdfViewer.memory(_pdfBytes!),
    );
  }
}
