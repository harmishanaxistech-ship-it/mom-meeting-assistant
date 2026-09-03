import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

class ExportDocumentScreen extends ConsumerStatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const ExportDocumentScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  ConsumerState<ExportDocumentScreen> createState() => _ExportDocumentScreenState();
}

class _ExportDocumentScreenState extends ConsumerState<ExportDocumentScreen> {
  String _selectedFormat = 'pdf'; // 'pdf' | 'docx'
  String _selectedLanguage = 'en'; // 'en' | 'hi' | 'gu'
  bool _isGenerating = false;

  String? _downloadedFilePath;
  String? _generatedFileName;

  Future<void> _generateAndDownloadDocument() async {
    setState(() {
      _isGenerating = true;
      _downloadedFilePath = null;
    });

    try {
      final client = ApiClient();

      // Step 1: Request backend to generate Document in selected language
      final response = await client.dio.post(
        '${ApiConstants.meetings}/${widget.meetingId}/document',
        data: {
          'format': _selectedFormat,
          'language': _selectedLanguage,
        },
      );

      if (response.data['success'] == true) {
        final doc = response.data['data']['document'];
        final downloadPath = response.data['data']['downloadUrl'];
        final fileName = doc['fileName'];

        // Step 2: Download the file to local device storage
        final dir = await getApplicationDocumentsDirectory();
        final localFilePath = '${dir.path}/$fileName';

        final fileUrl = '${ApiConstants.serverBaseUrl}$downloadPath';
        await client.dio.download(fileUrl, localFilePath);

        setState(() {
          _isGenerating = false;
          _downloadedFilePath = localFilePath;
          _generatedFileName = fileName;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppTheme.accentColor,
              content: Text('${_selectedFormat.toUpperCase()} generated in ${_getLanguageName(_selectedLanguage)}!'),
            ),
          );
        }
      } else {
        throw Exception(response.data['error'] ?? 'Document generation failed');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppTheme.errorColor,
            content: Text('Error: ${e.toString().replaceAll('Exception: ', '')}'),
          ),
        );
      }
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'hi':
        return 'Hindi';
      case 'gu':
        return 'Gujarati';
      default:
        return 'English';
    }
  }

  Future<void> _previewDocument() async {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      await OpenFilex.open(_downloadedFilePath!);
    }
  }

  Future<void> _shareGeneral() async {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_downloadedFilePath!)],
          subject: 'Minutes of Meeting - ${widget.meetingTitle}',
          text: 'Here are the minutes of meeting for ${widget.meetingTitle}.',
        ),
      );
    }
  }

  Future<void> _shareToWhatsApp() async {
    if (_downloadedFilePath != null && File(_downloadedFilePath!).existsSync()) {
      // WhatsApp sharing via file share sheet with pre-populated message
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_downloadedFilePath!)],
          subject: 'Minutes of Meeting - ${widget.meetingTitle}',
          text: '📄 Minutes of Meeting: *${widget.meetingTitle}*\nGenerated with MOM Assistant.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export MOM Document'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Meeting Title Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Target',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.meetingTitle,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Format Selection Card (PDF vs DOCX)
              const Text(
                '1. Select Document Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildOptionTile(
                      title: 'PDF Document',
                      subtitle: '.pdf file',
                      icon: Icons.picture_as_pdf,
                      iconColor: Colors.red,
                      isSelected: _selectedFormat == 'pdf',
                      onTap: () => setState(() => _selectedFormat = 'pdf'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildOptionTile(
                      title: 'Word Document',
                      subtitle: '.docx file',
                      icon: Icons.description,
                      iconColor: Colors.blue,
                      isSelected: _selectedFormat == 'docx',
                      onTap: () => setState(() => _selectedFormat = 'docx'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Language Selection Card
              const Text(
                '2. Select Document Language',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'en', label: Text('English')),
                      ButtonSegment(value: 'hi', label: Text('Hindi')),
                      ButtonSegment(value: 'gu', label: Text('Gujarati')),
                    ],
                    selected: {_selectedLanguage},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) setState(() => _selectedLanguage = set.first);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Generate Button
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _generateAndDownloadDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(
                  _isGenerating
                      ? 'Generating Document...'
                      : 'Generate in ${_getLanguageName(_selectedLanguage)} (${_selectedFormat.toUpperCase()})',
                ),
              ),
              const SizedBox(height: 24),

              // Generated Document Result View
              if (_downloadedFilePath != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withAlpha(20),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.accentColor.withAlpha(80)),
                  ),
                  child: Column(
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.accentColor, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Document Ready!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _generatedFileName ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _previewDocument,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          minimumSize: const Size.fromHeight(46),
                        ),
                        icon: const Icon(Icons.visibility),
                        label: const Text('Open & Preview Document'),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _shareToWhatsApp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF25D366),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(46),
                              ),
                              icon: const Icon(Icons.chat),
                              label: const Text('WhatsApp'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareGeneral,
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(46),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.share),
                              label: const Text('Share Other'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withAlpha(15) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 36),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? AppTheme.primaryColor : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
