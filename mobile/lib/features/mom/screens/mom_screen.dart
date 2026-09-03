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
        'keyDiscussionPoints': _discussionControllers.map((c) => c.text).toList(),
        'decisions': _decisionControllers.map((c) => c.text).toList(),
        'nextSteps': _nextStepsControllers.map((c) => c.text).toList(),
        'pendingItems': _pendingItemsControllers.map((c) => c.text).toList(),
        'risks': _risksControllers.map((c) => c.text).toList(),
      };

      final res = await client.dio.put(
        '${ApiConstants.meetings}/${widget.meetingId}/mom',
        data: updatedMom,
      );

      if (res.data['success'] == true && mounted) {
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
            content: Text('Translated to ${lang.toUpperCase()}'),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 1),
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

  @override
  Widget build(BuildContext context) {
    final actionItems = _mom?['actionItems'] as List? ?? [];

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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Embedded Meeting Audio Player (Listen & Scrub directly from MOM)
                  if (_audioFileName != null && _audioFileName!.isNotEmpty) ...[
                    AudioPlayerWidget(
                      audioUrl: '${ApiConstants.serverBaseUrl}/uploads/$_audioFileName',
                      title: _meetingTitle,
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Language Selector Bar
                  Container(
                    padding: const EdgeInsets.all(12),
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
                              'MOM Language (Cached instantly):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'en', label: Text('English')),
                              ButtonSegment(value: 'hi', label: Text('Hindi')),
                              ButtonSegment(value: 'gu', label: Text('Gujarati')),
                            ],
                            selected: {_selectedLanguage},
                            onSelectionChanged: (set) {
                              if (set.isNotEmpty) _changeLanguage(set.first);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 1. Executive Summary Card (Editable)
                  _buildSectionHeader(Icons.summarize_outlined, '1. Executive Summary'),
                  _buildEditableCard(
                    controller: _summaryController,
                    hint: 'Detailed executive summary...',
                  ),
                  const SizedBox(height: 20),

                  // 2. Key Discussion Points (Editable)
                  _buildSectionHeader(Icons.forum_outlined, '2. Key Discussion Points'),
                  if (_discussionControllers.isEmpty)
                    _buildEmptyBox('No discussion points recorded.')
                  else
                    _buildEditableList(
                      controllers: _discussionControllers,
                      icon: Icons.chat_bubble_outline,
                      color: AppTheme.primaryColor,
                    ),
                  const SizedBox(height: 20),

                  // 3. Decisions Taken (Editable)
                  _buildSectionHeader(Icons.gavel_outlined, '3. Decisions Taken'),
                  if (_decisionControllers.isEmpty)
                    _buildEmptyBox('No decisions recorded.')
                  else
                    _buildEditableList(
                      controllers: _decisionControllers,
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF10B981),
                    ),
                  const SizedBox(height: 20),

                  // 4. Action Items & Assignments
                  _buildSectionHeader(Icons.task_alt_outlined, '4. Action Items & Assignments'),
                  if (actionItems.isEmpty)
                    _buildEmptyBox('No action items extracted.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: actionItems.length,
                      itemBuilder: (ctx, i) {
                        final item = actionItems[i];
                        final isHigh = item['priority'] == 'High' || item['priority'] == 'उच्च';
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
                                ],
                              ),
                              const SizedBox(height: 12),
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
                  _buildSectionHeader(Icons.trending_up_outlined, '5. Next Steps & Upcoming To-Dos'),
                  if (_nextStepsControllers.isEmpty)
                    _buildEmptyBox('No immediate next steps.')
                  else
                    _buildEditableList(
                      controllers: _nextStepsControllers,
                      icon: Icons.arrow_forward_rounded,
                      color: const Color(0xFF6366F1),
                    ),
                  const SizedBox(height: 20),

                  // 6. Pending Items / Open Questions (Editable)
                  if (_pendingItemsControllers.isNotEmpty) ...[
                    _buildSectionHeader(Icons.help_outline_rounded, '6. Pending Items & Open Questions'),
                    _buildEditableList(
                      controllers: _pendingItemsControllers,
                      icon: Icons.question_mark_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 7. Risks & Blockers (Editable)
                  if (_risksControllers.isNotEmpty) ...[
                    _buildSectionHeader(Icons.warning_amber_rounded, '7. Risks & Dependencies'),
                    _buildEditableList(
                      controllers: _risksControllers,
                      icon: Icons.error_outline_rounded,
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 8. Conclusion (Editable)
                  _buildSectionHeader(Icons.done_all, '8. Conclusion'),
                  _buildEditableCard(
                    controller: _conclusionController,
                    hint: 'Detailed closing statement...',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
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
            onPressed: () {
              setState(() {
                controllers.removeAt(i);
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
