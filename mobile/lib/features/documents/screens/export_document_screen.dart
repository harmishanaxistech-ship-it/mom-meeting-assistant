import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_constants.dart';
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
          text: '📄 Minutes of Meeting: *${widget.meetingTitle}*\nGenerated with ${AppConstants.appName}.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export MOM Document',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              'Official Executive Documentation Studio',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Meeting Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E293B).withAlpha(6),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.article_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DOCUMENT TARGET',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF94A3B8),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.meetingTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Section 1: Format Selection (PDF vs Word)
              const Row(
                children: [
                  Text(
                    '1. Select Document Format',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildFormatTile(
                      format: 'pdf',
                      title: 'PDF Document',
                      extension: '.pdf',
                      badge: 'Executive Layout',
                      icon: Icons.picture_as_pdf_rounded,
                      accentColor: const Color(0xFFEF4444),
                      isSelected: _selectedFormat == 'pdf',
                      onTap: () => setState(() => _selectedFormat = 'pdf'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildFormatTile(
                      format: 'docx',
                      title: 'Word Document',
                      extension: '.docx',
                      badge: 'Fully Editable',
                      icon: Icons.description_rounded,
                      accentColor: const Color(0xFF2563EB),
                      isSelected: _selectedFormat == 'docx',
                      onTap: () => setState(() => _selectedFormat = 'docx'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section 2: Language Selection
              const Row(
                children: [
                  Text(
                    '2. Select Document Language',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildLanguageChip(
                      code: 'en',
                      label: 'English',
                      sublabel: 'Global Standard',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLanguageChip(
                      code: 'hi',
                      label: 'Hindi',
                      sublabel: 'हिंदी संस्करण',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLanguageChip(
                      code: 'gu',
                      label: 'Gujarati',
                      sublabel: 'ગુજરાતી સંસ્કરણ',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Primary Generate CTA Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _isGenerating ? null : _generateAndDownloadDocument,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isGenerating
                            ? [const Color(0xFF94A3B8), const Color(0xFF64748B)]
                            : [const Color(0xFF1E3A8A), const Color(0xFF2563EB)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        if (!_isGenerating)
                          BoxShadow(
                            color: const Color(0xFF1E3A8A).withAlpha(70),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isGenerating) ...[
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Generating Document...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ] else ...[
                          const Icon(Icons.download_rounded, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Generate in ${_getLanguageName(_selectedLanguage)} (${_selectedFormat.toUpperCase()})',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Generated Document Result View Card
              if (_downloadedFilePath != null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF10B981).withAlpha(100), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withAlpha(20),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Document Ready for Export!',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _generatedFileName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Preview Button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _previewDocument,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Open & Preview Document',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Share Buttons Row
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _shareToWhatsApp,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF25D366),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.chat_rounded, color: Colors.white, size: 17),
                                      SizedBox(width: 6),
                                      Text(
                                        'WhatsApp',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: _shareGeneral,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.share_rounded, color: Color(0xFF334155), size: 17),
                                      SizedBox(width: 6),
                                      Text(
                                        'Share Other',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF334155),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Footer
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Export Quality Verified • Powered by Anaxistech AI',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF94A3B8),
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
  }

  Widget _buildFormatTile({
    required String format,
    required String title,
    required String extension,
    required String badge,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF1E3A8A).withAlpha(16)
                    : const Color(0xFF1E293B).withAlpha(6),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: accentColor, size: 24),
                  ),
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? const Color(0xFF1E3A8A) : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFCBD5E1),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, size: 12, color: Colors.white)
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    extension,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageChip({
    required String code,
    required String label,
    required String sublabel,
  }) {
    final isSelected = _selectedLanguage == code;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedLanguage = code),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF1E3A8A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFF1E3A8A) : const Color(0xFFE2E8F0),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFF1E3A8A).withAlpha(25)
                    : const Color(0xFF1E293B).withAlpha(4),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                sublabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? const Color(0xFFBFDBFE) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
