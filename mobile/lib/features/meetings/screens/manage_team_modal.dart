import 'package:flutter/material.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ManageTeamModal extends StatefulWidget {
  final List<Map<String, dynamic>> currentTeam;
  final Function(List<Map<String, dynamic>>) onTeamUpdated;

  const ManageTeamModal({super.key, required this.currentTeam, required this.onTeamUpdated});

  @override
  State<ManageTeamModal> createState() => _ManageTeamModalState();
}

class _ManageTeamModalState extends State<ManageTeamModal> {
  late List<Map<String, dynamic>> _team;
  final _addController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _team = List.from(widget.currentTeam);
  }

  String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _addMember() async {
    final name = _capitalizeWords(_addController.text.trim());
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final res = await client.dio.post('/team', data: {'name': name});
      if (res.data['success']) {
        setState(() {
          _team.add(res.data['data']);
          _addController.clear();
        });
        widget.onTeamUpdated(_team);
      }
    } catch (e) {
      debugPrint('Error adding team member: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteMember(int index) async {
    final member = _team[index];
    final id = member['_id'];
    if (id == null) return;

    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final res = await client.dio.delete('/team/$id');
      if (res.data['success']) {
        setState(() {
          _team.removeAt(index);
        });
        widget.onTeamUpdated(_team);
      }
    } catch (e) {
      debugPrint('Error deleting team member: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _editMember(int index) async {
    final member = _team[index];
    final id = member['_id'];
    if (id == null) return;

    final editController = TextEditingController(text: member['name']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Team Member'),
        content: TextField(
          controller: editController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Member Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, editController.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && _capitalizeWords(newName) != member['name']) {
      final capitalizedName = _capitalizeWords(newName);
      setState(() => _isLoading = true);
      try {
        final client = ApiClient();
        final res = await client.dio.put('/team/$id', data: {'name': capitalizedName});
        if (res.data['success']) {
          setState(() {
            _team[index] = res.data['data'];
          });
          widget.onTeamUpdated(_team);
        }
      } catch (e) {
        debugPrint('Error updating team member: $e');
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 24, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Manage Master Directory', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _addController,
                  decoration: const InputDecoration(
                    hintText: 'Add to permanent directory...',
                    filled: true,
                  ),
                  onSubmitted: (_) => _addMember(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 36),
                onPressed: _addMember,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading) const Center(child: LinearProgressIndicator()),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _team.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (ctx, i) {
                final m = _team[i];
                return ListTile(
                  title: Text(m['name'] ?? ''),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.edit, size: 18), onPressed: () => _editMember(i)),
                      IconButton(icon: const Icon(Icons.delete, size: 18, color: Colors.red), onPressed: () => _deleteMember(i)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
