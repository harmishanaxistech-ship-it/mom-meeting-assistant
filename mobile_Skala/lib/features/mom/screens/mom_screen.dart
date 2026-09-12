import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/audio_player_widget.dart';
import '../../../core/services/local_audio_service.dart';
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
  String? _localAudioPath;
  bool _isTranslating = false;
  bool _isSaving = false;

  late TextEditingController _summaryController;
  late TextEditingController _conclusionController;
  List<TextEditingController> _discussionControllers = [];
  List<TextEditingController> _decisionControllers = [];
  List<TextEditingController> _nextStepsControllers = [];
  List<TextEditingController> _pendingItemsControllers = [];
  List<TextEditingController> _risksControllers = [];
  List<TextEditingController> _otherNotesControllers = [];
  bool _isInformalExpanded = false;

  // 1-2 min Spoken Audio Summary State
  bool _isGeneratingAudioSummary = false;
  bool _isRegeneratingMom = false;
  String _audioSummaryLanguage = 'en';
  Map<String, dynamic>? _currentAudioSummary;

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
    for (var c in _otherNotesControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _findLocalAudio() async {
    try {
      final path = await LocalAudioService.getLocalAudioPath(widget.meetingId);
      if (mounted && path != null) {
        setState(() {
          _localAudioPath = path;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchMOM() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _findLocalAudio();
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
          final audioSummaries = mom['audioSummaries'] as Map<String, dynamic>?;
          final cachedAudio = audioSummaries?[_audioSummaryLanguage] as Map<String, dynamic>?;
          setState(() {
            _mom = mom;
            _selectedLanguage = mom['language'] ?? 'en';
            _currentAudioSummary = cachedAudio;
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

  Future<void> _fetchOrGenerateAudioSummary(String lang, {bool forceRegenerate = false}) async {
    // 1. Check local cache in _mom if not force regenerating
    if (!forceRegenerate) {
      final audioSummaries = _mom?['audioSummaries'] as Map<String, dynamic>?;
      if (audioSummaries != null && audioSummaries[lang] != null) {
        setState(() {
          _audioSummaryLanguage = lang;
          _currentAudioSummary = Map<String, dynamic>.from(audioSummaries[lang]);
        });
        return;
      }
    }

    // 2. Request backend generation
    setState(() {
      _audioSummaryLanguage = lang;
      _isGeneratingAudioSummary = true;
    });

    try {
      final client = ApiClient();
      final res = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meetingId}/audio-summary',
        data: {
          'language': lang,
          'forceRegenerate': forceRegenerate,
        },
      );

      if (res.data['success'] == true && mounted) {
        final audioData = res.data['data'] as Map<String, dynamic>;
        if (_mom != null) {
          _mom!['audioSummaries'] ??= <String, dynamic>{};
          _mom!['audioSummaries'][lang] = audioData;
        }
        setState(() {
          _currentAudioSummary = audioData;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${lang == 'gu' ? 'Gujarati' : lang == 'hi' ? 'Hindi' : 'English'} voice briefing updated!',
            ),
            backgroundColor: AppTheme.primaryColor,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate audio summary: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingAudioSummary = false);
    }
  }

  Future<String?> _downloadAudioSummaryLocally() async {
    if (_currentAudioSummary == null || (_currentAudioSummary!['audioUrl'] ?? '').isEmpty) return null;
    try {
      setState(() => _isSaving = true);
      final String url = '${ApiConstants.serverBaseUrl}${_currentAudioSummary!['audioUrl']}';
      final String fileName = _currentAudioSummary!['audioUrl'].split('/').last;
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';
      
      final client = ApiClient();
      await client.dio.download(url, savePath);
      return savePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download audio: $e'), backgroundColor: Colors.red));
      }
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _shareAudioSummary() async {
    final path = await _downloadAudioSummaryLocally();
    if (path != null) {
      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Executive Briefing - $_meetingTitle');
    }
  }

  Future<void> _saveAudioSummary() async {
    final path = await _downloadAudioSummaryLocally();
    if (path != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = path.split('/').last;
      final newPath = '${docDir.path}/$fileName';
      await File(path).copy(newPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Audio saved to Documents folder!'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _isSavingOriginalAudio = false;

  Future<String?> _downloadOriginalAudioLocally() async {
    if (_localAudioPath != null && File(_localAudioPath!).existsSync()) {
      return _localAudioPath;
    }
    if (_audioFileName == null || _audioFileName!.isEmpty) return null;
    try {
      setState(() => _isSavingOriginalAudio = true);
      final String url = '${ApiConstants.serverBaseUrl}/uploads/$_audioFileName';
      final String fileName = _audioFileName!;
      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/$fileName';
      
      final client = ApiClient();
      await client.dio.download(url, savePath);
      return savePath;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to download original audio: $e'), backgroundColor: Colors.red));
      }
      return null;
    } finally {
      if (mounted) setState(() => _isSavingOriginalAudio = false);
    }
  }

  Future<void> _shareOriginalAudio() async {
    final path = await _downloadOriginalAudioLocally();
    if (path != null) {
      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Original Recording - $_meetingTitle');
    }
  }

  Future<void> _saveOriginalAudio() async {
    final path = await _downloadOriginalAudioLocally();
    if (path != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = path.split('/').last;
      final newPath = '${docDir.path}/$fileName';
      await File(path).copy(newPath);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Original Audio saved to Documents folder!'),
            backgroundColor: AppTheme.primaryColor,
            duration: Duration(seconds: 3),
          ),
        );
      }
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
    for (var c in _otherNotesControllers) {
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

    _otherNotesControllers = [];
    if (mom['otherNotes'] != null) {
      for (var n in mom['otherNotes']) {
        _otherNotesControllers.add(TextEditingController(text: n.toString()));
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
        'otherNotes': _otherNotesControllers.map((c) => c.text).where((t) => t.trim().isNotEmpty).toList(),
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
          _mom!['otherNotes'] = updatedMom['otherNotes'];
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

  bool get _hasMomError {
    final summary = _summaryController.text.toLowerCase();
    return summary.contains('gemini error') ||
        summary.contains('unavailable') ||
        summary.contains('503') ||
        summary.contains('spikes in demand') ||
        summary.contains('experiencing high demand') ||
        (summary.startsWith('error') && _discussionControllers.isEmpty && _actionItems.isEmpty);
  }

  Future<void> _regenerateMOM() async {
    if (_isRegeneratingMom) return;
    setState(() => _isRegeneratingMom = true);

    try {
      final client = ApiClient();
      final res = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meetingId}/regenerate-mom',
      );

      if (res.data['success'] == true && mounted) {
        final mom = res.data['data']['mom'];
        if (mom != null) {
          _populateControllers(mom);
          setState(() {
            _mom = mom;
            _selectedLanguage = 'en';
            _currentAudioSummary = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('MOM regenerated successfully with AI!'),
              backgroundColor: AppTheme.accentColor,
            ),
          );
        }
      } else {
        throw Exception(res.data['error'] ?? 'Regeneration failed');
      }
    } catch (e) {
      if (mounted) {
        String msg = e.toString();
        if (msg.contains('503') || msg.contains('high demand') || msg.contains('UNAVAILABLE')) {
          msg = 'Gemini AI is currently busy. Please tap Regenerate again in a few seconds.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isRegeneratingMom = false);
    }
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFDC2626),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'AI Generation Incomplete / 503 Spike',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF991B1B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'The AI model experienced a temporary spike in traffic while generating these Minutes of Meeting. Tap below to regenerate full structured MOM instantly.',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF7F1D1D),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: _isRegeneratingMom ? null : _regenerateMOM,
              icon: _isRegeneratingMom
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 20),
              label: Text(
                _isRegeneratingMom ? 'Regenerating MOM...' : 'Regenerate MOM with AI',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
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
                const SizedBox(height: 14),
                const Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: existingItem?['status'] ?? 'Not Started',
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Not Started', child: Text('Not Started ⚪')),
                    DropdownMenuItem(value: 'In Progress', child: Text('In Progress 🔵')),
                    DropdownMenuItem(value: 'Pending', child: Text('Pending 🟠')),
                    DropdownMenuItem(value: 'Delayed', child: Text('Delayed 🔴')),
                    DropdownMenuItem(value: 'Completed', child: Text('Completed 🟢')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => existingItem = {...?existingItem, 'status': val});
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
                  'status': existingItem?['status'] ?? 'Not Started',
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
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _meetingTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Minutes of Meeting Studio',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        actions: [
          if (!_isLoading)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: AppTheme.primaryColor, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_rounded, color: AppTheme.primaryColor, size: 20),
                tooltip: 'Save Edits',
                onPressed: _isSaving ? null : _saveChanges,
              ),
            ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withAlpha(40),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 19),
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
          ),
          if (!_isLoading) ...[
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded, color: Color(0xFF475569)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (val) {
                if (val == 'regenerate') {
                  _regenerateMOM();
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(
                  value: 'regenerate',
                  child: Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: AppTheme.primaryColor, size: 18),
                      SizedBox(width: 10),
                      Text(
                        'Regenerate MOM (AI)',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(8),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      color: AppTheme.primaryColor,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Loading Meeting Insights...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Prominent Error Banner if Gemini AI failed or spiked
                      if (_hasMomError) ...[
                        _buildErrorBanner(),
                      ],

                      // Meeting Header Banner Card
                      _buildMeetingHeroCard(),
                      const SizedBox(height: 14),

                      // Embedded Meeting Audio Player
                      if (_localAudioPath != null || (_audioFileName != null && _audioFileName!.isNotEmpty)) ...[
                        AudioPlayerWidget(
                          audioUrl: _localAudioPath ?? '${ApiConstants.serverBaseUrl}/uploads/$_audioFileName',
                          title: 'Original Recording - $_meetingTitle',
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic_rounded, size: 13, color: Color(0xFF475569)),
                                  SizedBox(width: 5),
                                  Text(
                                    'Full Raw Audio',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF475569),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_isSavingOriginalAudio)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 12),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                                    ),
                                  )
                                else ...[
                                  InkWell(
                                    onTap: _shareOriginalAudio,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.share_rounded, size: 12, color: Color(0xFF64748B)),
                                          SizedBox(width: 4),
                                          Text('Share', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: _saveOriginalAudio,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_rounded, size: 12, color: Color(0xFF64748B)),
                                          SizedBox(width: 4),
                                          Text('Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 1-2 Min Executive Voice Briefing Card
                      _buildVoiceBriefingCard(),
                      const SizedBox(height: 14),

                      // Language Selector Bar
                      _buildLanguageSelectorBar(),
                      const SizedBox(height: 20),

                      // 1. Executive Summary Card (Editable)
                      _buildSectionHeader(
                        icon: Icons.auto_awesome_rounded,
                        title: '1. Executive Summary',
                        badgeColor: const Color(0xFF3B82F6),
                      ),
                      _buildEditableCard(
                        controller: _summaryController,
                        hint: 'Detailed executive summary...',
                        accentColor: const Color(0xFF3B82F6),
                      ),
                      const SizedBox(height: 20),

                      // 2. Key Discussion Points (Editable)
                      _buildSectionHeader(
                        icon: Icons.forum_rounded,
                        title: '2. Key Discussion Points',
                        badgeColor: const Color(0xFF0284C7),
                        count: _discussionControllers.length,
                        onAdd: () => _addNewItem(_discussionControllers, 'Discussion Point'),
                      ),
                      if (_discussionControllers.isEmpty)
                        _buildEmptyBox('No discussion points recorded.', onAdd: () => _addNewItem(_discussionControllers, 'Discussion Point'))
                      else
                        _buildEditableList(
                          controllers: _discussionControllers,
                          icon: Icons.chat_bubble_outline_rounded,
                          color: const Color(0xFF0284C7),
                          itemType: 'discussion point',
                        ),
                      const SizedBox(height: 20),

                      // 3. Decisions Taken (Editable)
                      _buildSectionHeader(
                        icon: Icons.gavel_rounded,
                        title: '3. Decisions Taken',
                        badgeColor: const Color(0xFF059669),
                        count: _decisionControllers.length,
                        onAdd: () => _addNewItem(_decisionControllers, 'Decision'),
                      ),
                      if (_decisionControllers.isEmpty)
                        _buildEmptyBox('No decisions recorded.', onAdd: () => _addNewItem(_decisionControllers, 'Decision'))
                      else
                        _buildEditableList(
                          controllers: _decisionControllers,
                          icon: Icons.check_circle_outline_rounded,
                          color: const Color(0xFF059669),
                          itemType: 'decision',
                        ),
                      const SizedBox(height: 20),

                      // 4. Action Items & Assignments
                      _buildSectionHeader(
                        icon: Icons.task_alt_rounded,
                        title: '4. Action Items & Assignments',
                        badgeColor: const Color(0xFFD97706),
                        count: _actionItems.length,
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
                            final priorityStr = (item['priority'] ?? 'Medium').toString().toLowerCase();
                            final isHigh = priorityStr.contains('high') || priorityStr.contains('उच्च') || priorityStr.contains('ઉચ્ચ');
                            final isLow = priorityStr.contains('low') || priorityStr.contains('निम्न') || priorityStr.contains('ઓછી');

                            final badgeBg = isHigh
                                ? const Color(0xFFFEE2E2)
                                : isLow
                                    ? const Color(0xFFDCFCE7)
                                    : const Color(0xFFFEF3C7);
                            final badgeFg = isHigh
                                ? const Color(0xFFDC2626)
                                : isLow
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFFD97706);
                            final leftStripeColor = isHigh
                                ? const Color(0xFFEF4444)
                                : isLow
                                    ? const Color(0xFF22C55E)
                                    : const Color(0xFFF59E0B);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0F172A).withAlpha(8),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(color: leftStripeColor, width: 4),
                                    ),
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: leftStripeColor.withAlpha(20),
                                              borderRadius: BorderRadius.circular(9),
                                            ),
                                            child: Icon(
                                              Icons.check_box_outlined,
                                              size: 17,
                                              color: leftStripeColor,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              item['task'] ?? '',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14.5,
                                                color: Color(0xFF0F172A),
                                                height: 1.4,
                                                letterSpacing: -0.2,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                                                tooltip: 'Edit Action Item',
                                                onPressed: () => _showActionItemDialog(existingItem: item, index: i),
                                              ),
                                              IconButton(
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
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
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          if ((item['owner'] ?? '').isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.person_outline_rounded, size: 13, color: Color(0xFF475569)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item['owner'],
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if ((item['deadline'] ?? '').isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(Icons.schedule_rounded, size: 13, color: Color(0xFFB45309)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item['deadline'],
                                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if ((item['status'] ?? '').isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: item['status'] == 'Completed' ? const Color(0xFFDCFCE7) : item['status'] == 'Delayed' ? const Color(0xFFFEE2E2) : item['status'] == 'In Progress' ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    item['status'] == 'Completed' ? Icons.check_circle_outline : item['status'] == 'Delayed' ? Icons.warning_amber_rounded : item['status'] == 'In Progress' ? Icons.run_circle_outlined : Icons.info_outline_rounded,
                                                    size: 13, 
                                                    color: item['status'] == 'Completed' ? const Color(0xFF16A34A) : item['status'] == 'Delayed' ? const Color(0xFFDC2626) : item['status'] == 'In Progress' ? const Color(0xFF2563EB) : const Color(0xFF475569)
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    item['status'],
                                                    style: TextStyle(
                                                      fontSize: 11.5, 
                                                      fontWeight: FontWeight.w600, 
                                                      color: item['status'] == 'Completed' ? const Color(0xFF16A34A) : item['status'] == 'Delayed' ? const Color(0xFFDC2626) : item['status'] == 'In Progress' ? const Color(0xFF2563EB) : const Color(0xFF475569)
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: badgeBg,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 5,
                                                  height: 5,
                                                  decoration: BoxDecoration(
                                                    color: badgeFg,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 4.5),
                                                Text(
                                                  item['priority'] ?? 'Medium',
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: badgeFg,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 20),

                      // 5. Next Steps & Follow-ups (Editable)
                      _buildSectionHeader(
                        icon: Icons.trending_up_rounded,
                        title: '5. Next Steps & Upcoming To-Dos',
                        badgeColor: const Color(0xFF6366F1),
                        count: _nextStepsControllers.length,
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
                        badgeColor: const Color(0xFFEA580C),
                        count: _pendingItemsControllers.length,
                        onAdd: () => _addNewItem(_pendingItemsControllers, 'Pending Item'),
                      ),
                      if (_pendingItemsControllers.isEmpty)
                        _buildEmptyBox('No pending items recorded.', onAdd: () => _addNewItem(_pendingItemsControllers, 'Pending Item'))
                      else
                        _buildEditableList(
                          controllers: _pendingItemsControllers,
                          icon: Icons.question_mark_rounded,
                          color: const Color(0xFFEA580C),
                          itemType: 'pending item',
                        ),
                      const SizedBox(height: 20),

                      // 7. Risks & Blockers (Editable)
                      _buildSectionHeader(
                        icon: Icons.warning_amber_rounded,
                        title: '7. Risks & Dependencies',
                        badgeColor: const Color(0xFFDC2626),
                        count: _risksControllers.length,
                        onAdd: () => _addNewItem(_risksControllers, 'Risk'),
                      ),
                      if (_risksControllers.isEmpty)
                        _buildEmptyBox('No risks recorded.', onAdd: () => _addNewItem(_risksControllers, 'Risk'))
                      else
                        _buildEditableList(
                          controllers: _risksControllers,
                          icon: Icons.error_outline_rounded,
                          color: const Color(0xFFDC2626),
                          itemType: 'risk',
                        ),
                      const SizedBox(height: 20),

                      // 8. Informal / Side Discussions (Expandable Toggle)
                      _buildInformalSection(),
                      const SizedBox(height: 20),

                      // 9. Conclusion (Editable)
                      _buildSectionHeader(
                        icon: Icons.verified_rounded,
                        title: '9. Conclusion & Final Note',
                        badgeColor: const Color(0xFF0D9488),
                      ),
                      _buildEditableCard(
                        controller: _conclusionController,
                        hint: 'Detailed closing statement...',
                        accentColor: const Color(0xFF0D9488),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),

                // Global Translation Loader Overlay
                if (_isTranslating)
                  Container(
                    color: Colors.black.withAlpha(70),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Translating MOM to ${_selectedLanguage == 'gu' ? 'Gujarati' : _selectedLanguage == 'hi' ? 'Hindi' : 'English'}...',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Preserving context & bullet structure',
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

                // Global MOM Regeneration Loader Overlay
                if (_isRegeneratingMom)
                  Container(
                    color: Colors.black.withAlpha(70),
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 24,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFEFF6FF),
                                shape: BoxShape.circle,
                              ),
                              child: const CircularProgressIndicator(
                                color: AppTheme.primaryColor,
                                strokeWidth: 3,
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text(
                              'Regenerating MOM with AI...',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Analyzing discussion, actions, and decisions',
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

  Widget _buildMeetingHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withAlpha(45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome, size: 12, color: Color(0xFF93C5FD)),
                    SizedBox(width: 4),
                    Text(
                      'AI Minutes of Meeting',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_selectedLanguage.toUpperCase()} Mode',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _meetingTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.3,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildHeroStat(Icons.forum_outlined, '${_discussionControllers.length}', 'Points'),
              _buildHeroDivider(),
              _buildHeroStat(Icons.gavel_outlined, '${_decisionControllers.length}', 'Decisions'),
              _buildHeroDivider(),
              _buildHeroStat(Icons.task_alt_outlined, '${_actionItems.length}', 'Actions'),
              _buildHeroDivider(),
              _buildHeroStat(Icons.warning_amber_rounded, '${_risksControllers.length}', 'Risks'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String count, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 12, color: const Color(0xFF93C5FD)),
                const SizedBox(width: 4),
                Text(
                  count,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroDivider() {
    return const SizedBox(width: 6);
  }

  Widget _buildVoiceBriefingCard() {
    final langNames = {
      'en': 'English',
      'hi': 'Hindi',
      'gu': 'Gujarati',
    };
    final currentLangLabel = langNames[_audioSummaryLanguage] ?? 'English';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withAlpha(25)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(50),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Mic Badge + Title & Description
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0284C7).withAlpha(50),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  size: 20,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '1-2 Min Executive Voice Briefing',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Spoken AI summary in your chosen language',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Language Selector Bar
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(50),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withAlpha(15)),
            ),
            child: Row(
              children: [
                ...[
                  {'code': 'en', 'label': 'English'},
                  {'code': 'hi', 'label': 'हिंदी (Hindi)'},
                  {'code': 'gu', 'label': 'ગુજરાતી (Gujarati)'},
                ].map((l) {
                  final isSel = _audioSummaryLanguage == l['code'];
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: _isGeneratingAudioSummary
                          ? null
                          : () => _fetchOrGenerateAudioSummary(l['code']!),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? const Color(0xFF38BDF8) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSel
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF38BDF8).withAlpha(60),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  )
                                ]
                              : [],
                        ),
                        child: Text(
                          l['label']!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? const Color(0xFF0F172A) : const Color(0xFFCBD5E1),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Audio Player or Generation State
          if (_isGeneratingAudioSummary) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withAlpha(15)),
              ),
              child: Column(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF38BDF8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Synthesizing $currentLangLabel voice briefing...',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Generating AI spoken script & neural audio stream',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_currentAudioSummary != null &&
              (_currentAudioSummary!['audioUrl'] ?? '').isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dark Cohesive Audio Player
                AudioPlayerWidget(
                  key: ValueKey(_currentAudioSummary!['audioUrl']),
                  audioUrl: '${ApiConstants.serverBaseUrl}${_currentAudioSummary!['audioUrl']}',
                  title: 'Executive Briefing ($currentLangLabel)',
                  isDarkTheme: true,
                ),
                const SizedBox(height: 12),

                // Meta Info: Voice Actor Badge + Regenerate Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withAlpha(20),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF38BDF8).withAlpha(40)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.record_voice_over_rounded, size: 13, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 5),
                          Text(
                            'Voice: ${_currentAudioSummary!['voice'] ?? (_audioSummaryLanguage == 'gu' ? 'ગુજરાતી Native Voice' : _audioSummaryLanguage == 'hi' ? 'हिंदी Native Voice' : 'Indian English Native Voice')}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSaving)
                          const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF94A3B8)),
                            ),
                          )
                        else ...[
                          InkWell(
                            onTap: _shareAudioSummary,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: const Icon(Icons.share_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: _saveAudioSummary,
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              child: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        InkWell(
                          onTap: _isGeneratingAudioSummary
                              ? null
                              : () => _fetchOrGenerateAudioSummary(_audioSummaryLanguage, forceRegenerate: true),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Icon(Icons.replay_rounded, size: 14, color: Color(0xFF94A3B8)),
                                SizedBox(width: 4),
                                Text(
                                  'Regenerate',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                // View Script Accordion
                if ((_currentAudioSummary!['script'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Row(
                        children: const [
                          Icon(Icons.description_outlined, size: 15, color: Color(0xFF38BDF8)),
                          SizedBox(width: 6),
                          Text(
                            'View Spoken Voiceover Script',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withAlpha(50),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withAlpha(15)),
                          ),
                          child: Text(
                            _currentAudioSummary!['script'],
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.55,
                              color: Color(0xFFE2E8F0),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ] else ...[
            InkWell(
              onTap: () => _fetchOrGenerateAudioSummary(_audioSummaryLanguage),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withAlpha(40),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_circle_filled_rounded, size: 22, color: Color(0xFF0F172A)),
                    const SizedBox(width: 8),
                    Text(
                      'Generate & Play $currentLangLabel Briefing',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLanguageSelectorBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(6),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.translate_rounded, size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              const Text(
                'MOM Language (Multilingual Support)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              if (_isTranslating)
                Row(
                  children: const [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Translating...',
                      style: TextStyle(fontSize: 11.5, color: AppTheme.primaryColor, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildLangTab('en', 'English'),
              const SizedBox(width: 8),
              _buildLangTab('hi', 'Hindi (हिंदी)'),
              const SizedBox(width: 8),
              _buildLangTab('gu', 'Gujarati (ગુજરાતી)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLangTab(String code, String label) {
    final isSelected = _selectedLanguage == code;
    return Expanded(
      child: InkWell(
        onTap: _isTranslating ? null : () => _changeLanguage(code),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withAlpha(30),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInformalSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _isInformalExpanded,
          onExpansionChanged: (expanded) {
            setState(() => _isInformalExpanded = expanded);
          },
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 18,
              color: Color(0xFF64748B),
            ),
          ),
          title: Row(
            children: [
              const Text(
                '8. Informal / Side Discussions',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_otherNotesControllers.length}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          subtitle: const Text(
            'Casual banter, secondary remarks, non-core talk',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  const SizedBox(height: 12),
                  if (_otherNotesControllers.isEmpty)
                    _buildEmptyBox(
                      'No informal remarks recorded.',
                      onAdd: () => _addNewItem(_otherNotesControllers, 'Informal Note'),
                    )
                  else
                    _buildEditableList(
                      controllers: _otherNotesControllers,
                      icon: Icons.notes_rounded,
                      color: const Color(0xFF64748B),
                      itemType: 'informal note',
                    ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _addNewItem(_otherNotesControllers, 'Informal Note'),
                      icon: const Icon(Icons.add, size: 15, color: Color(0xFF64748B)),
                      label: const Text(
                        'Add Informal Note',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableCard({
    required TextEditingController controller,
    required String hint,
    Color accentColor = const Color(0xFF3B82F6),
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withAlpha(6),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: accentColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: TextField(
            controller: controller,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              filled: false,
              fillColor: Colors.transparent,
              hintText: hint,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            ),
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Color(0xFF1E293B),
              letterSpacing: 0.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableList({
    required List<TextEditingController> controllers,
    required IconData icon,
    required Color color,
    required String itemType,
  }) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: controllers.length,
      itemBuilder: (ctx, i) {
        final text = controllers[i].text;
        // Check if there is a bold/topic prefix like "**Topic**:" or "[Topic]:"
        String? topicHeader;
        if (text.startsWith('**') && text.contains('**:')) {
          final end = text.indexOf('**:');
          topicHeader = text.substring(2, end).trim();
        } else if (text.startsWith('[') && text.contains(']:')) {
          final end = text.indexOf(']:');
          topicHeader = text.substring(1, end).trim();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withAlpha(6),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: color, width: 4),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Badge + Optional Topic Header + Delete Icon
                  Row(
                    children: [
                      // Point Number Badge with Icon
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(22),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 12.5, color: color),
                            const SizedBox(width: 4.5),
                            Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (topicHeader != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            topicHeader,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: color,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ] else
                        const Spacer(),

                      // Delete Action Button
                      IconButton(
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Point Content Input with no border artifacts
                  TextField(
                    controller: controllers[i],
                    maxLines: null,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      filled: false,
                      fillColor: Colors.transparent,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.55,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyBox(String text, {VoidCallback? onAdd}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
          ),
          if (onAdd != null)
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 15, color: AppTheme.primaryColor),
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
    required Color badgeColor,
    int? count,
    VoidCallback? onAdd,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: badgeColor.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: badgeColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                if (count != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAdd != null)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onAdd,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: badgeColor),
                      const SizedBox(width: 3),
                      Text(
                        'Add',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
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


