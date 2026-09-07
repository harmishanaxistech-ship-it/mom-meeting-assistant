import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/audio_player_widget.dart';
import '../../documents/screens/export_document_screen.dart';

class MOMScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MOMScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MOMScreen> createState() => _MOMScreenState();
}

class _MOMScreenState extends ConsumerState<MOMScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _mom;
  String _meetingTitle = 'Minutes of Meeting';
  String _selectedLanguage = 'en';
  String? _audioFileName;
  bool _isTranslating = false;
  bool _isSaving = false;

  late TextEditingController _summaryController;
  late TextEditingController _conclusionController;
  List<TextEditingController> _discussionControllers = [];
  List<TextEditingController> _decisionControllers = [];
  List<TextEditingController> _nextStepsControllers = [];
  List<TextEditingController> _pendingItemsControllers = [];
  List<TextEditingController> _risksControllers = [];

  List<Map<String, dynamic>> _actionItems = [];

  @override
  void initState() {
    super.initState();
    _summaryController = TextEditingController();
    _conclusionController = TextEditingController();
    _fetchMOM();
  }

  @override
  void dispose() {
    _summaryController.dispose();
    _conclusionController.dispose();
    for (var c in _discussionControllers) {
      c.dispose();
    }
    for (var c in _decisionControllers) {
      c.dispose();
    }
    for (var c in _nextStepsControllers) {
      c.dispose();
    }
    for (var c in _pendingItemsControllers) {
      c.dispose();
    }
    for (var c in _risksControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchMOM() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final client = ApiClient();
      final res = await client.dio.get('${ApiConstants.meetings}/${widget.meetingId}');
      if (res.data['success'] == true) {
        final mom = res.data['data']['mom'];
        final meeting = res.data['data']['meeting'];
        if (meeting != null) {
          _meetingTitle = meeting['title'] ?? 'Minutes of Meeting';
          _audioFileName = meeting['audioFile']?['filename'];
        }
        if (mom != null && mounted) {
          _populateControllers(mom);
          setState(() {
            _mom = mom;
            _selectedLanguage = mom['language'] ?? 'en';
            _isLoading = false;
          });
          return;
        }
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers(Map<String, dynamic> mom) {
    _summaryController.text = mom['meetingSummary'] ?? '';
    _conclusionController.text = mom['conclusion'] ?? '';

    // Clear old controllers
    for (var c in _discussionControllers) {
      c.dispose();
    }
    for (var c in _decisionControllers) {
      c.dispose();
    }
    for (var c in _nextStepsControllers) {
      c.dispose();
    }
    for (var c in _pendingItemsControllers) {
      c.dispose();
    }
    for (var c in _risksControllers) {
      c.dispose();
    }

    _discussionControllers = [];
    if (mom['keyDiscussionPoints'] != null) {
      for (var point in mom['keyDiscussionPoints']) {
        _discussionControllers.add(TextEditingController(text: point.toString()));
      }
    }

    _decisionControllers = [];
    if (mom['decisions'] != null) {
      for (var dec in mom['decisions']) {
        _decisionControllers.add(TextEditingController(text: dec.toString()));
      }
    }

    _actionItems = [];
    if (mom['actionItems'] != null && mom['actionItems'] is List) {
      for (var item in mom['actionItems']) {
        _actionItems.add(Map<String, dynamic>.from(item));
      }
    }

    _nextStepsControllers = [];
    if (mom['nextSteps'] != null) {
      for (var step in mom['nextSteps']) {
        _nextStepsControllers.add(TextEditingController(text: step.toString()));
      }
    }

    _pendingItemsControllers = [];
    if (mom['pendingItems'] != null) {
      for (var p in mom['pendingItems']) {
        _pendingItemsControllers.add(TextEditingController(text: p.toString()));
      }
    }

    _risksControllers = [];
    if (mom['risks'] != null) {
      for (var r in mom['risks']) {
        _risksControllers.add(TextEditingController(text: r.toString()));
      }
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final client = ApiClient();
      final updatedMom = {
        'meetingSummary': _summaryController.text,
        'conclusion': _conclusionController.text,
        'keyDiscussionPoints': _discussionControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
        'decisions': _decisionControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
        'actionItems': _actionItems,
        'nextSteps': _nextStepsControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
        'pendingItems': _pendingItemsControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
        'risks': _risksControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
      };

      final res = await client.dio.put(
        '${ApiConstants.meetings}/${widget.meetingId}/mom',
        data: updatedMom,
      );

      if (res.data['success'] == true && mounted) {
        if (_mom != null) {
          _mom!['meetingSummary'] = updatedMom['meetingSummary'];
          _mom!['conclusion'] = updatedMom['conclusion'];
          _mom!['keyDiscussionPoints'] = updatedMom['keyDiscussionPoints'];
          _mom!['decisions'] = updatedMom['decisions'];
          _mom!['actionItems'] = updatedMom['actionItems'];
          _mom!['nextSteps'] = updatedMom['nextSteps'];
          _mom!['pendingItems'] = updatedMom['pendingItems'];
          _mom!['risks'] = updatedMom['risks'];
          _mom!['translations'] = {}; // Cleared on edit
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('MOM changes saved successfully!'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save changes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeLanguage(String lang) async {
    if (_selectedLanguage == lang || _isTranslating) return;

    // Check if translation is cached in _mom
    if (_mom != null &&
        _mom!['translations'] != null &&
        _mom!['translations'][lang] != null) {
      final cached = Map<String, dynamic>.from(_mom!['translations'][lang]);
      _populateControllers(cached);
      setState(() {
        _selectedLanguage = lang;
      });
      return;
    }

    setState(() => _isTranslating = true);
    try {
      final client = ApiClient();
      final res = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meetingId}/translate',
        data: {'targetLanguage': lang},
      );

      if (res.data['success'] == true && mounted) {
        final translatedData = res.data['data']['mom'];
        _populateControllers(translatedData);

        // Update local cache
        if (_mom != null) {
          _mom!['translations'] ??= {};
          _mom!['translations'][lang] = translatedData;
        }

        setState(() {
          _selectedLanguage = lang;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translated to ${lang == 'gu' ? 'Gujarati' : lang == 'hi' ? 'Hindi' : 'English'}'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Translation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTranslating = false);
    }
  }

  Future<bool> _confirmDelete(String itemTitle, {String? previewText}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(30),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Badge with soft red ring
              Padding(
                padding: const EdgeInsets.only(top: 28, bottom: 12),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 3),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.delete_forever_rounded,
                      size: 32,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
              ),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'Delete ${itemTitle.split(' ').map((s) => s.isNotEmpty ? '${s[0].toUpperCase()}${s.substring(1)}' : '').join(' ')}?',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Subtitle
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  'This action will remove the $itemTitle from this meeting\'s MOM.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ),

              // Optional Preview snippet of the item being deleted
              if (previewText != null && previewText.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 16, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          previewText.trim(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Action Buttons Row
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Delete button with gradient or bold red
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result ?? false;
  }

  void _addNewItem(List<TextEditingController> controllers, String hint) {
    final newController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Add $hint', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: TextField(
          controller: newController,
          maxLines: 3,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter $hint details...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              if (newController.text.trim().isNotEmpty) {
                setState(() {
                  controllers.add(newController);
                });
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showActionItemDialog({Map<String, dynamic>? existingItem, int? index}) {
    final taskCtrl = TextEditingController(text: existingItem?['task'] ?? '');
    final ownerCtrl = TextEditingController(text: existingItem?['owner'] ?? '');
    final deadlineCtrl = TextEditingController(text: existingItem?['deadline'] ?? '');
    String priority = existingItem?['priority'] ?? 'Medium';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(
                existingItem != null ? Icons.edit_note_outlined : Icons.add_task_outlined,
                color: AppTheme.primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                existingItem != null ? 'Edit Action Item' : 'New Action Item',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Task Description *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: taskCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g. Share testing checklist',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Assignee / Owner', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: ownerCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Harmish Sejpal',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Deadline / Due Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: deadlineCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Tomorrow EOD, Friday',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Priority', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'High', child: Text('High Priority (🔴)')),
                    DropdownMenuItem(value: 'Medium', child: Text('Medium Priority (🟡)')),
                    DropdownMenuItem(value: 'Low', child: Text('Low Priority (🟢)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => priority = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                if (taskCtrl.text.trim().isEmpty) return;
                final newItem = {
                  'task': taskCtrl.text.trim(),
                  'owner': ownerCtrl.text.trim(),
                  'deadline': deadlineCtrl.text.trim(),
                  'priority': priority,
                };
                setState(() {
                  if (index != null) {
                    _actionItems[index] = newItem;
                  } else {
                    _actionItems.add(newItem);
                  }
                });
                Navigator.of(ctx).pop();
              },
              child: Text(existingItem != null ? 'Update' : 'Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _meetingTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              tooltip: 'Save Edits',
              onPressed: _isSaving ? null : _saveChanges,
            ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Export & Share PDF/Docx',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ExportDocumentScreen(
                    meetingId: widget.meetingId,
                    meetingTitle: _meetingTitle,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Embedded Meeting Audio Player
                      if (_audioFileName != null && _audioFileName!.isNotEmpty) ...[
                        AudioPlayerWidget(
                          audioUrl: '${ApiConstants.serverBaseUrl}/uploads/$_audioFileName',
                          title: _meetingTitle,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Language Selector Bar
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.translate, size: 18, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                const Text(
                                  'MOM Language (Multilingual Support):',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                const Spacer(),
                                if (_isTranslating)
                                  Row(
                                    children: const [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Translating...',
                                        style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: SegmentedButton<String>(
                                emptySelectionAllowed: false,
                                multiSelectionEnabled: false,
                                segments: const [
                                  ButtonSegment(value: 'en', label: Text('English')),
                                  ButtonSegment(value: 'hi', label: Text('Hindi')),
                                  ButtonSegment(value: 'gu', label: Text('Gujarati')),
                                ],
                                selected: {_selectedLanguage},
                                onSelectionChanged: _isTranslating
                                    ? null
                                    : (set) {
                                        if (set.isNotEmpty) _changeLanguage(set.first);
                                      },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 1. Executive Summary Card (Editable)
                      _buildSectionHeader(
                        icon: Icons.summarize_outlined,
                        title: '1. Executive Summary',
                      ),
                      _buildEditableCard(
                        controller: _summaryController,
                        hint: 'Detailed executive summary...',
                      ),
                      const SizedBox(height: 20),

                      // 2. Key Discussion Points (Editable)
                      _buildSectionHeader(
                        icon: Icons.forum_outlined,
                        title: '2. Key Discussion Points',
                        onAdd: () => _addNewItem(_discussionControllers, 'Discussion Point'),
                      ),
                      if (_discussionControllers.isEmpty)
                        _buildEmptyBox('No discussion points recorded.', onAdd: () => _addNewItem(_discussionControllers, 'Discussion Point'))
                      else
                        _buildEditableList(
                          controllers: _discussionControllers,
                          icon: Icons.chat_bubble_outline,
                          color: AppTheme.primaryColor,
                          itemType: 'discussion point',
                        ),
                      const SizedBox(height: 20),

                      // 3. Decisions Taken (Editable)
                      _buildSectionHeader(
                        icon: Icons.gavel_outlined,
                        title: '3. Decisions Taken',
                        onAdd: () => _addNewItem(_decisionControllers, 'Decision'),
                      ),
                      if (_decisionControllers.isEmpty)
                        _buildEmptyBox('No decisions recorded.', onAdd: () => _addNewItem(_decisionControllers, 'Decision'))
                      else
                        _buildEditableList(
                          controllers: _decisionControllers,
                          icon: Icons.check_circle_outline,
                          color: const Color(0xFF10B981),
                          itemType: 'decision',
                        ),
                      const SizedBox(height: 20),

                      // 4. Action Items & Assignments
                      _buildSectionHeader(
                        icon: Icons.task_alt_outlined,
                        title: '4. Action Items & Assignments',
                        onAdd: () => _showActionItemDialog(),
                      ),
                      if (_actionItems.isEmpty)
                        _buildEmptyBox('No action items extracted.', onAdd: () => _showActionItemDialog())
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _actionItems.length,
                          itemBuilder: (ctx, i) {
                            final item = _actionItems[i];
                            final isHigh = item['priority'] == 'High' || item['priority'] == 'उच्च' || item['priority'] == 'ઉચ્ચ';
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha(5),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.assignment_outlined,
                                          size: 18,
                                          color: isHigh ? Colors.red : AppTheme.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          item['task'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppTheme.textPrimary,
                                            height: 1.4,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                        tooltip: 'Edit Action Item',
                                        onPressed: () => _showActionItemDialog(existingItem: item, index: i),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                        tooltip: 'Delete Action Item',
                                        onPressed: () async {
                                          final confirmed = await _confirmDelete(
                                            'action item',
                                            previewText: item['task'] as String?,
                                          );
                                          if (confirmed && mounted) {
                                            setState(() {
                                              _actionItems.removeAt(i);
                                            });
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    children: [
                                      if ((item['owner'] ?? '').isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.person, size: 14, color: Color(0xFF475569)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Owner: ${item['owner']}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if ((item['deadline'] ?? '').isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF3C7),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.alarm, size: 14, color: Color(0xFFB45309)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Due: ${item['deadline']}',
                                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isHigh ? const Color(0xFFFEE2E2) : const Color(0xFFE0E7FF),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Priority: ${item['priority'] ?? 'Medium'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isHigh ? const Color(0xFFDC2626) : const Color(0xFF4338CA),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // 5. Next Steps & Follow-ups (Editable)
                      _buildSectionHeader(
                        icon: Icons.trending_up_outlined,
                        title: '5. Next Steps & Upcoming To-Dos',
                        onAdd: () => _addNewItem(_nextStepsControllers, 'Next Step'),
                      ),
                      if (_nextStepsControllers.isEmpty)
                        _buildEmptyBox('No immediate next steps.', onAdd: () => _addNewItem(_nextStepsControllers, 'Next Step'))
                      else
                        _buildEditableList(
                          controllers: _nextStepsControllers,
                          icon: Icons.arrow_forward_rounded,
                          color: const Color(0xFF6366F1),
                          itemType: 'next step',
                        ),
                      const SizedBox(height: 20),

                      // 6. Pending Items / Open Questions (Editable)
                      _buildSectionHeader(
                        icon: Icons.help_outline_rounded,
                        title: '6. Pending Items & Open Questions',
                        onAdd: () => _addNewItem(_pendingItemsControllers, 'Pending Item'),
                      ),
                      if (_pendingItemsControllers.isEmpty)
                        _buildEmptyBox('No pending items recorded.', onAdd: () => _addNewItem(_pendingItemsControllers, 'Pending Item'))
                      else
                        _buildEditableList(
                          controllers: _pendingItemsControllers,
                          icon: Icons.question_mark_rounded,
                          color: const Color(0xFFF59E0B),
                          itemType: 'pending item',
                        ),
                      const SizedBox(height: 20),

                      // 7. Risks & Blockers (Editable)
                      _buildSectionHeader(
                        icon: Icons.warning_amber_rounded,
                        title: '7. Risks & Dependencies',
                        onAdd: () => _addNewItem(_risksControllers, 'Risk'),
                      ),
                      if (_risksControllers.isEmpty)
                        _buildEmptyBox('No risks recorded.', onAdd: () => _addNewItem(_risksControllers, 'Risk'))
                      else
                        _buildEditableList(
                          controllers: _risksControllers,
                          icon: Icons.error_outline_rounded,
                          color: const Color(0xFFEF4444),
                          itemType: 'risk',
                        ),
                      const SizedBox(height: 20),

                      // 8. Conclusion (Editable)
                      _buildSectionHeader(
                        icon: Icons.done_all,
                        title: '8. Conclusion',
                      ),
                      _buildEditableCard(
                        controller: _conclusionController,
                        hint: 'Detailed closing statement...',
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),

                // Global Translation Loader Overlay
                if (_isTranslating)
                  Container(
                    color: Colors.black.withAlpha(50),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(25),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                              strokeWidth: 3,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Translating MOM to ${_selectedLanguage == 'gu' ? 'Gujarati' : _selectedLanguage == 'hi' ? 'Hindi' : 'English'}...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Using AI translator',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildEditableCard({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: TextField(
        controller: controller,
        maxLines: null,
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          isDense: true,
        ),
        style: const TextStyle(fontSize: 14, height: 1.5, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildEditableList({
    required List<TextEditingController> controllers,
    required IconData icon,
    required Color color,
    required String itemType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controllers.length,
        separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
        itemBuilder: (ctx, i) => ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          title: TextField(
            controller: controllers[i],
            maxLines: null,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
            ),
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textPrimary),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
            tooltip: 'Delete $itemType',
            onPressed: () async {
              final confirmed = await _confirmDelete(
                itemType,
                previewText: controllers[i].text,
              );
              if (confirmed && mounted) {
                setState(() {
                  controllers.removeAt(i);
                });
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBox(String text, {VoidCallback? onAdd}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
              label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          if (onAdd != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, size: 16, color: AppTheme.primaryColor),
                      SizedBox(width: 4),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

