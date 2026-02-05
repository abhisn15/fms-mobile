import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/shift_assignment_model.dart';
import '../../models/shift_model.dart';
import '../../models/team_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/team_service.dart';
import '../../widgets/shimmer_loading.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  final TeamService _teamService = TeamService();
  final bool _leaderReadOnly = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  static const int _pageSize = 10;
  int _memberPage = 0;

  bool _isLoading = false;
  bool _isManageLoading = false;
  String? _error;
  String? _manageError;

  bool _isLeader = false;
  List<TeamSummary> _leaderTeams = [];
  List<TeamSummary> _myTeams = [];
  Map<String, List<TeamMember>> _leaderMembersByTeam = {};
  Set<String> _selectedLeaderTeamIds = {};
  String? _selectedTeamId; // for employee team selection
  String? _manageTeamId; // for leader manage shift

  List<TeamMember> _members = [];
  List<TeamMember> _manageMembers = [];
  List<DailyShift> _shifts = [];
  List<ShiftAssignment> _assignments = [];

  String? _selectedMemberId;
  String? _selectedShiftId;
  DateTime _selectedDate = DateTime.now();
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, 1);
    _endDate = DateTime(now.year, now.month + 1, 0);
    _loadTeamData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamData() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final leaderTeams = await _teamService.getLeaderTeams();
      if (!mounted) return;

      if (leaderTeams.isNotEmpty) {
        _isLeader = true;
        _leaderTeams = leaderTeams;
        _myTeams = [];

        if (_manageTeamId == null || !_leaderTeams.any((team) => team.id == _manageTeamId)) {
          _manageTeamId = _leaderTeams.first.id;
        }

        if (_selectedLeaderTeamIds.isEmpty) {
          _selectedLeaderTeamIds = _leaderTeams.map((team) => team.id).toSet();
        }

        _leaderMembersByTeam = await _fetchLeaderMembers(_leaderTeams);
        _members = _mergeLeaderMembers(_selectedLeaderTeamIds);
        _manageMembers = _leaderMembersByTeam[_manageTeamId] ?? [];

        await _loadManageData();
      } else {
        _isLeader = false;
        _leaderTeams = [];
        _leaderMembersByTeam = {};
        _selectedLeaderTeamIds = {};

        _myTeams = await _teamService.getMyTeamsWithMembers();
        if (_myTeams.isNotEmpty) {
          final teamIds = _myTeams.map((team) => team.id).toSet();
          if (_selectedTeamId == null || !teamIds.contains(_selectedTeamId)) {
            _selectedTeamId = _myTeams.first.id;
          }
          final selectedTeam = _myTeams.firstWhere(
            (team) => team.id == _selectedTeamId,
            orElse: () => _myTeams.first,
          );
          _members = selectedTeam.members;
        } else {
          _members = [];
        }
      }
    } on TeamServiceException catch (e) {
      if (e.statusCode == 403) {
        _isLeader = false;
        try {
          _myTeams = await _teamService.getMyTeamsWithMembers();
          if (_myTeams.isNotEmpty) {
            _selectedTeamId = _myTeams.first.id;
            _members = _myTeams.first.members;
          }
        } catch (inner) {
          _error = inner.toString().replaceAll('Exception: ', '');
        }
      } else {
        _error = e.message;
      }
    } catch (e) {
      _error = e.toString().replaceAll('Exception: ', '');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<Map<String, List<TeamMember>>> _fetchLeaderMembers(List<TeamSummary> teams) async {
    final entries = await Future.wait(teams.map((team) async {
      final members = await _teamService.getLeaderTeamMembers(teamId: team.id);
      return MapEntry(team.id, members);
    }));
    return Map<String, List<TeamMember>>.fromEntries(entries);
  }

  List<TeamMember> _mergeLeaderMembers(Set<String> teamIds) {
    final map = <String, TeamMember>{};
    for (final teamId in teamIds) {
      final members = _leaderMembersByTeam[teamId] ?? [];
      for (final member in members) {
        if (member.id.isNotEmpty) {
          map[member.id] = member;
        }
      }
    }
    return map.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  List<TeamMember> _filterMembers(List<TeamMember> members) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return members;
    return members.where((member) {
      final name = member.name.toLowerCase();
      final nik = (member.externalId ?? '').toLowerCase();
      final phone = (member.phone ?? '').toLowerCase();
      final site = (member.siteName ?? '').toLowerCase();
      return name.contains(query) ||
          nik.contains(query) ||
          phone.contains(query) ||
          site.contains(query);
    }).toList();
  }

  List<T> _paginateList<T>(List<T> items, int page) {
    final start = page * _pageSize;
    if (start >= items.length) return [];
    final end = (start + _pageSize).clamp(0, items.length);
    return items.sublist(start, end);
  }

  int _totalPages(int total) {
    if (total == 0) return 1;
    return (total / _pageSize).ceil();
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _memberPage = 0;
        });
      },
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Cari nama, NIK, nomor HP, atau site',
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildTeamInfoCard(TeamSummary team) {
    return _buildSectionCard(
      title: 'Info Team',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Nama Team', team.name),
          const SizedBox(height: 8),
          _buildInfoRow('Team Leader', team.leaderName),
          const SizedBox(height: 8),
          _buildInfoRow('Jumlah Anggota', team.memberCount.toString()),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value.isNotEmpty ? value : '-',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Future<void> _loadManageData() async {
    if (_isManageLoading || !_isLeader || _manageTeamId == null) return;
    setState(() {
      _isManageLoading = true;
      _manageError = null;
    });

    try {
      final shifts = await _teamService.getLeaderShiftMaster();
      final assignments = await _teamService.getLeaderShiftAssignments(
        teamId: _manageTeamId!,
        startDate: _startDate,
        endDate: _endDate,
      );

      final members = _leaderMembersByTeam[_manageTeamId] ??
          await _teamService.getLeaderTeamMembers(teamId: _manageTeamId!);
      final memberIds = members.map((m) => m.id).where((id) => id.isNotEmpty).toSet();
      final filteredAssignments = assignments.where((assignment) {
        final ownerId = assignment.ownerId ?? assignment.owner?.id;
        if (ownerId == null) return false;
        return memberIds.contains(ownerId);
      }).toList();

      if (!mounted) return;
      setState(() {
        _manageMembers = members;
        _shifts = shifts;
        _assignments = filteredAssignments;

        final memberIds = members.map((m) => m.id).toSet();
        final shiftIds = shifts.map((s) => s.id).toSet();
        if (_selectedMemberId == null || !memberIds.contains(_selectedMemberId)) {
          _selectedMemberId = members.isNotEmpty ? members.first.id : null;
        }
        if (_selectedShiftId == null || !shiftIds.contains(_selectedShiftId)) {
          _selectedShiftId = shifts.isNotEmpty ? shifts.first.id : null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _manageError = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isManageLoading = false;
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('id', 'ID'),
      helpText: 'Pilih Rentang Tanggal',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadManageData();
    }
  }

  Future<void> _assignShift() async {
    if (_manageTeamId == null || _selectedMemberId == null || _selectedShiftId == null) {
      return;
    }
    setState(() {
      _isManageLoading = true;
      _manageError = null;
    });
    try {
      await _teamService.assignShift(
        teamId: _manageTeamId!,
        date: _selectedDate,
        dailyShiftId: _selectedShiftId!,
        ownerIds: [_selectedMemberId!],
      );
      await _loadManageData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift anggota berhasil ditambahkan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isManageLoading = false;
        });
      }
    }
  }

  Future<void> _deleteAssignment(ShiftAssignment assignment) async {
    if (_manageTeamId == null) return;
    setState(() {
      _isManageLoading = true;
    });
    try {
      await _teamService.deleteShiftAssignment(
        teamId: _manageTeamId!,
        assignmentId: assignment.id,
      );
      await _loadManageData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isManageLoading = false;
        });
      }
    }
  }

  TeamSummary? _currentTeam() {
    return _myTeams.firstWhere(
      (team) => team.id == _selectedTeamId,
      orElse: () => _myTeams.isNotEmpty ? _myTeams.first : TeamSummary(id: '', name: '-', leaderName: '-', memberCount: 0),
    );
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  ShiftAssignment? _findAssignmentFor(DateTime date, String? memberId) {
    if (memberId == null) return null;
    for (final assignment in _assignments) {
      if (assignment.ownerId != memberId) continue;
      final parsed = DateTime.tryParse(assignment.date);
      if (parsed == null) continue;
      if (_isSameDate(parsed, date)) {
        return assignment;
      }
    }
    return null;
  }

  List<DateTime> _buildDateRange() {
    final dates = <DateTime>[];
    var current = DateTime(_startDate.year, _startDate.month, _startDate.day);
    final end = DateTime(_endDate.year, _endDate.month, _endDate.day);
    while (!current.isAfter(end)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }
    return dates;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context).user;
    final currentUserId = user?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTeamData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_isLoading)
              _buildSkeletonScreen()
            else if (_error != null)
              _buildErrorCard()
            else ...[
              if (_isLeader) _buildLeaderSummary(),
              if (_isLeader) const SizedBox(height: 16),
              if (_isLeader) _buildLeaderTeamFilter(),
              if (_isLeader) const SizedBox(height: 12),
              if (!_isLeader && _myTeams.length > 1) _buildEmployeeTeamSelector(),
              if (!_isLeader && _myTeams.length > 1) const SizedBox(height: 12),
              if (!_isLeader && _myTeams.isNotEmpty) _buildTeamInfoCard(_currentTeam()!),
              if (!_isLeader && _myTeams.isNotEmpty) const SizedBox(height: 12),
              if (!_isLeader && _myTeams.isNotEmpty) _buildSearchBar(),
              if (!_isLeader && _myTeams.isNotEmpty) const SizedBox(height: 12),
              if (_isLeader)
                _buildMemberList(currentUserId)
              else
                _buildMemberTable(currentUserId),
              if (_isLeader) const SizedBox(height: 20),
              if (_isLeader) _buildManageShiftSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderSummary() {
    final totalMembers = _leaderMembersByTeam.values.fold<int>(0, (sum, members) => sum + members.length);
    return Row(
      children: [
        Expanded(
          child: _buildKpiCard(
            label: 'Team Dipimpin',
            value: _leaderTeams.length.toString(),
            color: Colors.blue,
            icon: Icons.groups,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildKpiCard(
            label: 'Total Anggota',
            value: totalMembers.toString(),
            color: Colors.green,
            icon: Icons.people,
          ),
        ),
      ],
    );
  }

  Widget _buildLeaderTeamFilter() {
    if (_leaderTeams.isEmpty) return const SizedBox.shrink();
    final allSelected = _selectedLeaderTeamIds.length == _leaderTeams.length;

    return _buildSectionCard(
      title: 'Filter Team',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: const Text('Semua'),
              selected: allSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedLeaderTeamIds = _leaderTeams.map((team) => team.id).toSet();
                  } else {
                    _selectedLeaderTeamIds = {};
                  }
                  _members = _mergeLeaderMembers(_selectedLeaderTeamIds);
                });
              },
            ),
            const SizedBox(width: 8),
            ..._leaderTeams.map((team) {
              final selected = _selectedLeaderTeamIds.contains(team.id);
              final label = team.name.isNotEmpty ? team.name : '(Tanpa Nama Team)';
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      if (value) {
                        _selectedLeaderTeamIds.add(team.id);
                      } else {
                        _selectedLeaderTeamIds.remove(team.id);
                      }
                      _members = _mergeLeaderMembers(_selectedLeaderTeamIds);
                    });
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmployeeTeamSelector() {
    return _buildSectionCard(
      title: 'Pilih Team',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedTeamId,
          isExpanded: true,
          items: _myTeams
              .map(
                (team) => DropdownMenuItem(
                  value: team.id,
                  child: Text(
                    team.leaderName.isNotEmpty
                        ? '${team.leaderName} — ${team.name.isNotEmpty ? team.name : '(Tanpa Nama Team)'}'
                        : (team.name.isNotEmpty ? team.name : '(Tanpa Nama Team)'),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null || value == _selectedTeamId) return;
            final selected = _myTeams.firstWhere((team) => team.id == value, orElse: () => _myTeams.first);
            setState(() {
              _selectedTeamId = value;
              _members = selected.members;
            });
          },
        ),
      ),
    );
  }

  Widget _buildMemberList(String? currentUserId) {
    final filtered = _filterMembers(_members);
    final totalMembers = filtered.length;
    return _buildSectionCard(
      title: 'Anggota Team',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            totalMembers > 0 ? 'Total anggota: $totalMembers' : 'Belum ada anggota team',
            style: TextStyle(color: Colors.grey[700]),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: totalMembers == 0 ? null : () => _showMembersModal(currentUserId),
              icon: const Icon(Icons.people_alt_outlined),
              label: const Text('Lihat Anggota'),
            ),
          ),
        ],
      ),
    );
  }

  void _showMembersModal(String? currentUserId) {
    final controller = TextEditingController(text: _searchQuery);
    int page = _memberPage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = _filterMembers(_members);
            final totalPages = _totalPages(filtered.length);
            if (page >= totalPages) page = 0;
            final pageItems = _paginateList(filtered, page);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Daftar Anggota',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _memberPage = 0;
                      });
                      setModalState(() {
                        page = 0;
                      });
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Cari nama, NIK, nomor HP, atau site',
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Tidak ada anggota sesuai pencarian',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _buildMemberCard(
                          pageItems[index],
                          currentUserId: currentUserId,
                        ),
                      ),
                    ),
                  if (filtered.isNotEmpty) const SizedBox(height: 8),
                  if (filtered.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: page > 0
                              ? () {
                                  setModalState(() {
                                    page -= 1;
                                  });
                                }
                              : null,
                          child: const Text('Sebelumnya'),
                        ),
                        Text('Hal ${page + 1} / $totalPages'),
                        TextButton(
                          onPressed: page + 1 < totalPages
                              ? () {
                                  setModalState(() {
                                    page += 1;
                                  });
                                }
                              : null,
                          child: const Text('Berikutnya'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMemberTable(String? currentUserId) {
    if (_members.isEmpty && _myTeams.isEmpty) {
      return _buildSectionCard(
        title: 'Susunan Team',
        child: Text(
          'Belum ada team yang terhubung dengan akun Anda',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final team = _currentTeam();
    final leaderName = team?.leaderName ?? 'Tanpa Leader';
    final filtered = _filterMembers(_members);
    final leaderRow = <String, String>{
      'name': leaderName,
      'title': 'Leader',
      'role': 'Leader',
      'id': '',
    };
    return _buildSectionCard(
      title: 'Susunan Team',
      child: Column(
        children: [
          _buildTableHeader(),
          const SizedBox(height: 8),
          _buildTableRow(
            name: leaderRow['name'] ?? '-',
            title: leaderRow['title'] ?? '-',
            role: leaderRow['role'] ?? '-',
          ),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Tidak ada anggota sesuai pencarian',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ...filtered.map((member) {
              final isMe = member.id.isNotEmpty && member.id == currentUserId;
              return _buildTableRow(
                name: member.name,
                title: member.title ?? member.positionName ?? 'Anggota',
                role: 'Anggota',
                highlight: isMe,
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: const Row(
        children: [
          Expanded(flex: 3, child: Text('Nama', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: Text('Jabatan', style: TextStyle(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: Text('Role', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildTableRow({
    required String name,
    required String title,
    required String role,
    bool highlight = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: highlight ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: highlight ? Colors.grey[400]! : Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(name)),
          Expanded(flex: 3, child: Text(title)),
          Expanded(flex: 2, child: Text(role)),
        ],
      ),
    );
  }

  Widget _buildManageShiftSection() {
    final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
    final totalAssignments = _assignments.length;
    final uniqueMembers = _assignments
        .map((assignment) => assignment.ownerId ?? assignment.owner?.id)
        .whereType<String>()
        .toSet()
        .length;
    final bkoCount = _assignments.where(_isBackupAssignment).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jadwal Shift Team',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        if (_leaderReadOnly) ...[
          const SizedBox(height: 6),
          Text(
            'Leader hanya bisa memantau jadwal. Jika ada kesalahan, hubungi supervisor.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final teamCard = _buildSectionCard(
              title: 'Team',
              child: _leaderTeams.length <= 1
                  ? Text(
                      _leaderTeams.isNotEmpty ? _leaderTeams.first.name : '-',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _manageTeamId,
                        isExpanded: true,
                        items: _leaderTeams
                            .map((team) => DropdownMenuItem(
                                  value: team.id,
                                  child: Text(team.name),
                                ))
                            .toList(),
                        onChanged: (value) async {
                          if (value == null || value == _manageTeamId) return;
                          setState(() {
                            _manageTeamId = value;
                            _manageMembers = _leaderMembersByTeam[value] ?? [];
                          });
                          await _loadManageData();
                        },
                      ),
                    ),
            );
            final quickActionCard = _buildSectionCard(
              title: 'Aksi Cepat',
              child: _isManageLoading
                  ? Column(
                      children: [
                        ShimmerLoading(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(10)),
                        const SizedBox(height: 10),
                        ShimmerLoading(width: double.infinity, height: 44, borderRadius: BorderRadius.circular(10)),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _manageTeamId == null ? null : _showScheduleModal,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: const Text('Lihat Jadwal'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Total jadwal di rentang ini: $totalAssignments',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
            );
            final dateCard = _buildSectionCard(
              title: 'Rentang Tanggal',
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${dateFormatter.format(_startDate)} - ${dateFormatter.format(_endDate)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _pickDateRange,
                    child: const Text('Ubah'),
                  ),
                ],
              ),
            );
            
            final monitoringCard = _buildMonitoringSummaryCard(
              totalAssignments: totalAssignments,
              uniqueMembers: uniqueMembers,
              bkoCount: bkoCount,
            );

            if (isWide) {
              // Put Team and Aksi Cepat side by side, and Date below them
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team
                  Expanded(
                    child: teamCard,
                  ),
                  const SizedBox(width: 12),
                  // Aksi Cepat
                  Expanded(
                    child: quickActionCard,
                  ),
                  // You can add more Expanded here if spacing needed between quickActionCard and below row
                ],
              );
            }

            // Not wide: show vertically
            return Column(
              children: [
                teamCard,
                const SizedBox(height: 12),
                quickActionCard,
                const SizedBox(height: 12),
                dateCard,
                const SizedBox(height: 12),
                monitoringCard,
              ],
            );
          },
        ),
        if (_manageError != null) ...[
          const SizedBox(height: 12),
          _buildErrorCard(message: _manageError),
        ],
      ],
    );
  }

  bool _isBackupAssignment(ShiftAssignment assignment) {
    final note = assignment.notes?.toLowerCase() ?? '';
    return note.contains('menggantikan') || note.contains('backup') || note.contains('bko');
  }

  Widget _buildMonitoringSummaryCard({
    required int totalAssignments,
    required int uniqueMembers,
    required int bkoCount,
  }) {
    return _buildSectionCard(
      title: 'Monitoring Shift',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Total jadwal', totalAssignments.toString()),
          _buildInfoRow('Anggota terjadwal', uniqueMembers.toString()),
          _buildInfoRow('BKO/Backup', bkoCount.toString()),
          const SizedBox(height: 6),
          Text(
            'Monitoring bersifat read-only.',
            style: TextStyle(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  List<_AssignmentGroup> _groupAssignments() {
    final map = <String, _AssignmentGroup>{};
    for (final assignment in _assignments) {
      final parsed = DateTime.tryParse(assignment.date);
      if (parsed == null) continue;
      final shift = assignment.dailyShift;
      final shiftId = shift?.id ?? 'unknown';
      final key = '${parsed.toIso8601String().split('T').first}|$shiftId';
      final existing = map[key];
      if (existing == null) {
        map[key] = _AssignmentGroup(date: parsed, shift: shift, items: [assignment]);
      } else {
        existing.items.add(assignment);
      }
    }
    final groups = map.values.toList();
    groups.sort((a, b) {
      final dateCompare = b.date.compareTo(a.date);
      if (dateCompare != 0) return dateCompare;
      final nameA = a.shift?.name ?? '';
      final nameB = b.shift?.name ?? '';
      return nameA.compareTo(nameB);
    });
    return groups;
  }

  void _showAssignShiftModal() {
    if (_manageTeamId == null) return;
    final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Tambah Shift',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Tanggal'),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDate: _selectedDate,
                        locale: const Locale('id', 'ID'),
                        helpText: 'Pilih Tanggal',
                        cancelText: 'Batal',
                        confirmText: 'Pilih',
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                        setModalState(() {});
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(dateFormatter.format(_selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Anggota'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedMemberId,
                    items: _manageMembers
                        .map((member) => DropdownMenuItem(
                              value: member.id,
                              child: Text(member.name),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedMemberId = value;
                      });
                      setModalState(() {});
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  const Text('Shift'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: _selectedShiftId,
                    items: _shifts
                        .map((shift) => DropdownMenuItem(
                              value: shift.id,
                              child: Text('${shift.name} (${shift.startTime}-${shift.endTime})'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedShiftId = value;
                      });
                      setModalState(() {});
                    },
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (_isManageLoading || _selectedMemberId == null || _selectedShiftId == null)
                          ? null
                          : () async {
                              Navigator.pop(context);
                              await _assignShift();
                            },
                      icon: const Icon(Icons.save),
                      label: const Text('Simpan Shift'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showScheduleModal() {
    final dateFormatter = DateFormat('dd MMM yyyy', 'id_ID');
    final groups = _groupAssignments();
    final memberMap = {for (final member in _manageMembers) member.id: member};
    int page = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPages = _totalPages(groups.length);
            if (page >= totalPages) page = 0;
            final pageItems = _paginateList(groups, page);

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Jadwal Shift Team',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dateFormatter.format(_startDate)} - ${dateFormatter.format(_endDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'Belum ada jadwal di rentang ini',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: pageItems.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final group = pageItems[index];
                          final shift = group.shift;
                          final shiftName = shift?.name ?? 'Shift';
                          final uniqueCount = group.items
                              .map((item) => item.ownerId ?? item.owner?.id)
                              .whereType<String>()
                              .toSet()
                              .length;
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        dateFormatter.format(group.date),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$shiftName (${shift?.startTime ?? '-'}-${shift?.endTime ?? '-'})',
                                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Total anggota: $uniqueCount',
                                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _showAssignmentDetailModal(group, memberMap),
                                  child: const Text('Detail'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  if (groups.isNotEmpty) const SizedBox(height: 8),
                  if (groups.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: page > 0
                              ? () {
                                  setModalState(() {
                                    page -= 1;
                                  });
                                }
                              : null,
                          child: const Text('Sebelumnya'),
                        ),
                        Text('Hal ${page + 1} / $totalPages'),
                        TextButton(
                          onPressed: page + 1 < totalPages
                              ? () {
                                  setModalState(() {
                                    page += 1;
                                  });
                                }
                              : null,
                          child: const Text('Berikutnya'),
                        ),
                      ],
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAssignmentDetailModal(_AssignmentGroup group, Map<String, TeamMember> memberMap) {
    int page = 0;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final totalPages = _totalPages(group.items.length);
            if (page >= totalPages) page = 0;
            final pageItems = _paginateList(group.items, page);
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Detail Anggota',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: pageItems.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final assignment = pageItems[index];
                          final ownerId = assignment.ownerId ?? assignment.owner?.id;
                          final member = ownerId != null ? memberMap[ownerId] : null;
                          final owner = assignment.owner;
                          final name = member?.name ?? owner?.name ?? 'Anggota';
                          final siteName = member?.siteName ?? owner?.site ?? '-';
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(name),
                                    const SizedBox(height: 4),
                                    Text(
                                      siteName,
                                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    if (assignment.notes != null && assignment.notes!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        assignment.notes!,
                                        style: TextStyle(color: Colors.grey[700], fontSize: 11),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (!_leaderReadOnly)
                                IconButton(
                                  onPressed: () async {
                                    await _deleteAssignment(assignment);
                                    setModalState(() {});
                                  },
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: page > 0
                            ? () {
                                setModalState(() {
                                  page -= 1;
                                });
                              }
                            : null,
                        child: const Text('Sebelumnya'),
                      ),
                      Text('Hal ${page + 1} / $totalPages'),
                      TextButton(
                        onPressed: page + 1 < totalPages
                            ? () {
                                setModalState(() {
                                  page += 1;
                                });
                              }
                            : null,
                        child: const Text('Berikutnya'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAssignmentsList(DateFormat dateFormatter) {
    if (_assignments.isEmpty) {
      return _buildSectionCard(
        title: 'Jadwal Shift Anggota',
        child: Text(
          'Belum ada jadwal di rentang ini',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    final memberMap = {for (final member in _manageMembers) member.id: member};

    return _buildSectionCard(
      title: 'Jadwal Shift Anggota',
      child: Column(
        children: _assignments.map((assignment) {
          final ownerId = assignment.ownerId ?? assignment.owner?.id;
          final owner = ownerId != null ? memberMap[ownerId] : null;
          final shift = assignment.dailyShift;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        owner?.name ?? 'Anggota',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateFormatter.format(DateTime.parse(assignment.date)),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (shift?.color != null
                                  ? Color(int.parse('FF${shift!.color!.replaceAll('#', '')}', radix: 16))
                                  : Colors.blue)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${shift?.name ?? '-'} (${shift?.startTime ?? '-'}-${shift?.endTime ?? '-'})',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_leaderReadOnly)
                  IconButton(
                    onPressed: () => _deleteAssignment(assignment),
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Hapus shift',
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMemberCard(TeamMember member, {String? currentUserId}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          _buildMemberAvatar(member),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  [member.title, member.siteName].where((item) => (item ?? '').isNotEmpty).join(' - '),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                if (member.externalId != null &&
                    member.externalId!.isNotEmpty &&
                    member.id == currentUserId) ...[
                  const SizedBox(height: 2),
                  Text(
                    'NIK: ${member.externalId}',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
                if (member.teamName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.teamName ?? '-',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatar(TeamMember member) {
    if (member.photoUrl != null && member.photoUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 22,
        backgroundImage: NetworkImage(member.photoUrl!),
      );
    }
    final initials = member.name
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0])
        .take(2)
        .join()
        .toUpperCase();
    final bgColor = member.avatarColor != null && member.avatarColor!.isNotEmpty
        ? Color(int.parse(member.avatarColor!.replaceAll('#', '0xFF')))
        : Colors.blueGrey;
    return CircleAvatar(
      radius: 22,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorCard({String? message}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message ?? _error ?? 'Gagal memuat data team',
            style: TextStyle(color: Colors.red[700]),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _loadTeamData,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSkeletonCard(height: 90),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 140),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 220),
      ],
    );
  }

  Widget _buildSkeletonCard({double height = 120}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: 160, height: 16, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 12),
          ShimmerLoading(width: double.infinity, height: height, borderRadius: BorderRadius.circular(12)),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }
}

class _AssignmentGroup {
  _AssignmentGroup({
    required this.date,
    required this.shift,
    required this.items,
  });

  final DateTime date;
  final DailyShift? shift;
  final List<ShiftAssignment> items;
}
