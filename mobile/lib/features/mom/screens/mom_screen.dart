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

    for (var c in _discussionControllers) {
      c.dispose();
    }
    for (var c in _decisionControllers) {
      c.dispose();
    }

    final points = (mom['keyDiscussionPoints'] as List<dynamic>?) ?? [];
    _discussionControllers =
        points.map((p) => TextEditingController(text: p.toString())).toList();

    final decisions = (mom['decisions'] as List<dynamic>?) ?? [];
    _decisionControllers =
        decisions.map((d) => TextEditingController(text: d.toString())).toList();
  }

  Future<void> _saveMOMEdits() async {
    if (!mounted) return;
    setState(() => _isSaving = true);

    try {
      final client = ApiClient();
      final updatedPoints =
          _discussionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      final updatedDecisions =
          _decisionControllers.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();

      final res = await client.dio.put(
        '${ApiConstants.meetings}/${widget.meetingId}/mom',
        data: {
          'meetingSummary': _summaryController.text.trim(),
          'conclusion': _conclusionController.text.trim(),
          'keyDiscussionPoints': updatedPoints,
          'decisions': updatedDecisions,
          'actionItems': _mom?['actionItems'] ?? [],
        },
      );

      if (res.data['success'] == true && mounted) {
        final savedMom = res.data['data']['mom'];
        setState(() {
          _mom = savedMom;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppTheme.accentColor,
            content: Text('✓ Changes saved successfully!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _changeLanguage(String lang) async {
    if (lang == _selectedLanguage || !mounted) return;
    setState(() {
      _isTranslating = true;
    });

    try {
      final client = ApiClient();
      final res = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meetingId}/translate',
        data: {'targetLanguage': lang},
      );

      if (res.data['success'] == true && mounted) {
        final translated = res.data['data']['mom'];
        _populateControllers(translated);
        setState(() {
          _mom = translated;
          _selectedLanguage = lang;
          _isTranslating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isTranslating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Translation error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minutes of Meeting (MOM)')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_mom == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Minutes of Meeting (MOM)')),
        body: const Center(
          child: Text('No MOM generated yet. Record & process the meeting first.'),
        ),
      );
    }

    final actionItems = (_mom!['actionItems'] as List<dynamic>?) ?? [];
    final tokenUsage = _mom!['tokenUsage'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minutes of Meeting'),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            tooltip: 'Save Edits',
            onPressed: _isSaving ? null : _saveMOMEdits,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF / Word',
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
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving ? null : _saveMOMEdits,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Edits'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.download),
                  label: const Text('Export Document'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _isTranslating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Translating MOM with OpenAI...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OpenAI Token Usage Banner
                  if (tokenUsage != null && (tokenUsage['totalTokens'] ?? 0) > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, color: Color(0xFF16A34A), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'OpenAI Tokens Used: ${tokenUsage['totalTokens']} (${tokenUsage['promptTokens']} prompt + ${tokenUsage['completionTokens']} output)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF166534),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOM Language (Cached after 1st translation):',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
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

                  // Meeting Summary Card (Editable)
                  _buildSectionHeader(Icons.summarize_outlined, 'Executive Summary (Editable)'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _summaryController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Edit executive summary...',
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Key Discussion Points (Editable)
                  _buildSectionHeader(Icons.chat_bubble_outline, 'Key Discussion Points (Editable)'),
                  if (_discussionControllers.isEmpty)
                    const Text('No discussion points recorded.')
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _discussionControllers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => ListTile(
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primaryColor.withAlpha(25),
                            child: Text('${i + 1}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor)),
                          ),
                          title: TextField(
                            controller: _discussionControllers[i],
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _discussionControllers.removeAt(i);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Decisions (Editable)
                  _buildSectionHeader(Icons.gavel_outlined, 'Decisions Taken (Editable)'),
                  if (_decisionControllers.isEmpty)
                    const Text('No decisions recorded.')
                  else
                    Card(
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _decisionControllers.length,
                        separatorBuilder: (context, index) => const Divider(height: 1),
                        itemBuilder: (ctx, i) => ListTile(
                          leading: const Icon(Icons.check_circle_outline, color: AppTheme.accentColor),
                          title: TextField(
                            controller: _decisionControllers[i],
                            maxLines: null,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18, color: Colors.grey),
                            onPressed: () {
                              setState(() {
                                _decisionControllers.removeAt(i);
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Action Items
                  _buildSectionHeader(Icons.task_alt_outlined, 'Action Items'),
                  if (actionItems.isEmpty)
                    const Text('No action items extracted.')
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: actionItems.length,
                      itemBuilder: (ctx, i) {
                        final item = actionItems[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item['task'] ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    if ((item['owner'] ?? '').isNotEmpty)
                                      Chip(
                                        avatar: const Icon(Icons.person, size: 14),
                                        label: Text('Owner: ${item['owner']}',
                                            style: const TextStyle(fontSize: 11)),
                                      ),
                                    if ((item['deadline'] ?? '').isNotEmpty)
                                      Chip(
                                        avatar: const Icon(Icons.alarm, size: 14),
                                        label: Text('Due: ${item['deadline']}',
                                            style: const TextStyle(fontSize: 11)),
                                      ),
                                    Chip(
                                      backgroundColor: item['priority'] == 'High' ||
                                              item['priority'] == 'उच्च'
                                          ? Colors.red.withAlpha(25)
                                          : Colors.blue.withAlpha(25),
                                      label: Text(
                                        'Priority: ${item['priority'] ?? 'Medium'}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: item['priority'] == 'High' ||
                                                  item['priority'] == 'उच्च'
                                              ? Colors.red
                                              : Colors.blue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Conclusion (Editable)
                  const SizedBox(height: 20),
                  _buildSectionHeader(Icons.done_all, 'Conclusion (Editable)'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        controller: _conclusionController,
                        maxLines: null,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Edit conclusion / next steps...',
                        ),
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
