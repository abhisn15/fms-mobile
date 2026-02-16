import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/team_model.dart';
import '../../models/team_task_model.dart';
import '../../services/team_service.dart';

class TeamTasksScreen extends StatefulWidget {
  final bool isLeader;
  final List<TeamSummary> teams;
  final Map<String, List<TeamMember>> membersByTeam;
  final String? initialTeamId;

  const TeamTasksScreen({
    super.key,
    required this.isLeader,
    required this.teams,
    required this.membersByTeam,
    this.initialTeamId,
  });

  @override
  State<TeamTasksScreen> createState() => _TeamTasksScreenState();
}

class _TeamTasksScreenState extends State<TeamTasksScreen> {
  final TeamService _teamService = TeamService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _statusFilter = '';
  String? _selectedTeamId;
  String? _selectedAssigneeId;
  DateTime? _dueDate;
  List<TeamTask> _tasks = [];

  static const Map<String, String> _statusLabel = {
    'todo': 'To Do',
    'in_progress': 'Dikerjakan',
    'done': 'Selesai',
    'cancelled': 'Batal',
  };

  static const Map<String, Color> _statusColor = {
    'todo': Color(0xFF2563EB),
    'in_progress': Color(0xFFF59E0B),
    'done': Color(0xFF10B981),
    'cancelled': Color(0xFFEF4444),
  };

  @override
  void initState() {
    super.initState();
    _selectedTeamId =
        widget.initialTeamId ??
        (widget.teams.isNotEmpty ? widget.teams.first.id : null);
    _syncAssigneeToTeam();
    _loadTasks();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _syncAssigneeToTeam() {
    if (!widget.isLeader) return;
    final members = _selectedTeamId == null
        ? <TeamMember>[]
        : (widget.membersByTeam[_selectedTeamId] ?? []);
    final memberIds = members.map((e) => e.id).toSet();
    if (_selectedAssigneeId == null ||
        !memberIds.contains(_selectedAssigneeId)) {
      _selectedAssigneeId = members.isNotEmpty ? members.first.id : null;
    }
  }

  Future<void> _loadTasks() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tasks = widget.isLeader
          ? await _teamService.getLeaderTasks(
              teamId: _selectedTeamId,
              status: _statusFilter.isEmpty ? null : _statusFilter,
            )
          : await _teamService.getMyTasks(
              status: _statusFilter.isEmpty ? null : _statusFilter,
            );

      if (!mounted) return;
      setState(() {
        _tasks = tasks;
      });
    } on TeamServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
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

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      initialDate: _dueDate ?? now,
      locale: const Locale('id', 'ID'),
    );
    if (picked != null) {
      setState(() {
        _dueDate = DateTime(picked.year, picked.month, picked.day, 8, 0);
      });
    }
  }

  Future<void> _createTask() async {
    if (!widget.isLeader) return;
    final teamId = _selectedTeamId;
    final assigneeId = _selectedAssigneeId;
    final title = _titleController.text.trim();
    if (teamId == null || assigneeId == null) {
      _showSnack('Team dan anggota wajib dipilih', isError: true);
      return;
    }
    if (title.length < 3) {
      _showSnack('Judul tugas minimal 3 karakter', isError: true);
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _teamService.createLeaderTask(
        teamId: teamId,
        assigneeId: assigneeId,
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        dueDate: _dueDate,
      );
      if (!mounted) return;
      _titleController.clear();
      _descriptionController.clear();
      setState(() {
        _dueDate = null;
      });
      _showSnack('Tugas berhasil dibuat');
      await _loadTasks();
    } on TeamServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _updateTaskStatus(TeamTask task, String status) async {
    if (status == task.status) return;
    try {
      if (widget.isLeader) {
        await _teamService.updateLeaderTask(task.id, status: status);
      } else {
        await _teamService.updateMyTaskStatus(task.id, status);
      }
      if (!mounted) return;
      _showSnack('Status tugas diperbarui');
      await _loadTasks();
    } on TeamServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteTask(TeamTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus tugas'),
        content: Text('Hapus tugas "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _teamService.deleteLeaderTask(task.id);
      if (!mounted) return;
      _showSnack('Tugas dihapus');
      await _loadTasks();
    } on TeamServiceException catch (e) {
      _showSnack(e.message, isError: true);
    } catch (e) {
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';
    return DateFormat('dd MMM yyyy', 'id_ID').format(date.toLocal());
  }

  Widget _buildStatusChip(String status) {
    final color = _statusColor[status] ?? Colors.blueGrey;
    final label = _statusLabel[status] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teamMembers = _selectedTeamId == null
        ? <TeamMember>[]
        : (widget.membersByTeam[_selectedTeamId] ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isLeader ? 'Tugas Team Leader' : 'Tugas Saya'),
        backgroundColor: const Color(0xFF1E88E5),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTasks,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.isLeader)
              Card(
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Buat Tugas Anggota',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _selectedTeamId,
                        decoration: const InputDecoration(labelText: 'Team'),
                        items: widget.teams
                            .map(
                              (team) => DropdownMenuItem(
                                value: team.id,
                                child: Text(team.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedTeamId = value;
                            _syncAssigneeToTeam();
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: _selectedAssigneeId,
                        decoration: const InputDecoration(labelText: 'Anggota'),
                        items: teamMembers
                            .map(
                              (member) => DropdownMenuItem(
                                value: member.id,
                                child: Text(
                                  member.externalId?.isNotEmpty == true
                                      ? '${member.name} (${member.externalId})'
                                      : member.name,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedAssigneeId = value),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Judul tugas',
                          hintText: 'Contoh: Cek area rawat inap lantai 3',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Detail tugas (opsional)',
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickDueDate,
                              icon: const Icon(Icons.date_range_outlined),
                              label: Text(
                                _dueDate == null
                                    ? 'Pilih deadline'
                                    : _formatDate(_dueDate),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_dueDate != null)
                            IconButton(
                              tooltip: 'Hapus deadline',
                              onPressed: () => setState(() => _dueDate = null),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _createTask,
                          icon: const Icon(Icons.add_task),
                          label: Text(
                            _isSaving ? 'Menyimpan...' : 'Tambah Tugas',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Card(
              elevation: 1,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text('Filter status:'),
                    ChoiceChip(
                      label: const Text('Semua'),
                      selected: _statusFilter.isEmpty,
                      onSelected: (_) async {
                        setState(() => _statusFilter = '');
                        await _loadTasks();
                      },
                    ),
                    ...['todo', 'in_progress', 'done', 'cancelled'].map((
                      status,
                    ) {
                      final selected = _statusFilter == status;
                      return ChoiceChip(
                        label: Text(_statusLabel[status] ?? status),
                        selected: selected,
                        onSelected: (_) async {
                          setState(() => _statusFilter = status);
                          await _loadTasks();
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else if (_tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    widget.isLeader
                        ? 'Belum ada tugas team'
                        : 'Belum ada tugas untuk Anda',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              )
            else
              ..._tasks.map((task) {
                final dueText = task.dueDate != null
                    ? _formatDate(task.dueDate)
                    : '-';
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                task.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            _buildStatusChip(task.status),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (task.description != null &&
                            task.description!.trim().isNotEmpty)
                          Text(
                            task.description!,
                            style: TextStyle(color: Colors.grey.shade800),
                          ),
                        const SizedBox(height: 8),
                        Text('Team: ${task.team?.name ?? '-'}'),
                        Text('Assignee: ${task.assignee?.name ?? '-'}'),
                        Text('Dibuat oleh: ${task.createdBy?.name ?? '-'}'),
                        Text('Deadline: $dueText'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ...[
                              'todo',
                              'in_progress',
                              'done',
                              if (widget.isLeader) 'cancelled',
                            ].map(
                              (status) => OutlinedButton(
                                onPressed: () =>
                                    _updateTaskStatus(task, status),
                                child: Text(_statusLabel[status] ?? status),
                              ),
                            ),
                            if (widget.isLeader)
                              OutlinedButton.icon(
                                onPressed: () => _deleteTask(task),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                label: const Text(
                                  'Hapus',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
