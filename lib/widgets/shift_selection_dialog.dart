import 'package:flutter/material.dart';
import '../models/shift_model.dart';

class ShiftSelectionDialog extends StatefulWidget {
  final List<DailyShift> shifts;
  final DailyShift? selectedShift;
  final Function(DailyShift) onShiftSelected;

  const ShiftSelectionDialog({
    super.key,
    required this.shifts,
    this.selectedShift,
    required this.onShiftSelected,
  });

  @override
  State<ShiftSelectionDialog> createState() => _ShiftSelectionDialogState();
}

class _ShiftSelectionDialogState extends State<ShiftSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<DailyShift> _filteredShifts = [];

  @override
  void initState() {
    super.initState();
    _filteredShifts = widget.shifts;
    _searchController.addListener(_filterShifts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterShifts() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredShifts = widget.shifts;
      } else {
        _filteredShifts = widget.shifts.where((shift) {
          final nameMatch = shift.name.toLowerCase().contains(query);
          final codeMatch = shift.code.toLowerCase().contains(query);
          final timeMatch = shift.startTime.toLowerCase().contains(query) ||
              shift.endTime.toLowerCase().contains(query);
          return nameMatch || codeMatch || timeMatch;
        }).toList();
      }
    });
  }

  Color _getShiftColor(DailyShift shift) {
    if (shift.color != null) {
      return Color(int.parse(
        'FF${shift.color!.replaceAll('#', '')}',
        radix: 16,
      ));
    }
    return Colors.blue;
  }


  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Pilih Shift',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search Bar
            if (widget.shifts.length > 3)
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari shift...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[600]),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            
            if (widget.shifts.length > 3) const SizedBox(height: 16),
            
            // Shifts List
            if (_filteredShifts.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Shift tidak ditemukan'
                            : 'Tidak ada shift yang tersedia',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _filteredShifts.length,
                  itemBuilder: (context, index) {
                    final shift = _filteredShifts[index];
                    final isSelected = widget.selectedShift?.id == shift.id;
                    final shiftColor = _getShiftColor(shift);
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? shiftColor : Colors.grey[300]!,
                          width: isSelected ? 2.5 : 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        color: isSelected ? shiftColor.withOpacity(0.1) : Colors.white,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: shiftColor.withOpacity(0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onShiftSelected(shift);
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                // Shift Icon
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: shiftColor,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: shiftColor.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  // Hanya warna, tanpa teks (menghilangkan nama shift di dalam lingkaran)
                                  child: null,
                                ),
                                const SizedBox(width: 16),
                                // Shift Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        shift.name,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: isSelected
                                              ? shiftColor
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 14,
                                            color: isSelected
                                                ? shiftColor
                                                : Colors.grey[600],
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${shift.startTime} - ${shift.endTime}',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: isSelected
                                                  ? shiftColor.withOpacity(0.8)
                                                  : Colors.grey[600],
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                // Selection Indicator
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected ? shiftColor : Colors.grey[400]!,
                                      width: 2,
                                    ),
                                    color: isSelected ? shiftColor : Colors.transparent,
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

