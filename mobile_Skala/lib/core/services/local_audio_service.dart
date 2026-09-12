import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class LocalAudioService {
  static const String audioFolderName = 'NoteAX_Recordings';

  /// Get the dedicated local storage directory for meeting audio files
  static Future<Directory> getAudioDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final audioDir = Directory('${docsDir.path}/$audioFolderName');
    if (!audioDir.existsSync()) {
      audioDir.createSync(recursive: true);
    }
    return audioDir;
  }

  /// Get standard target file path for a meeting recording
  static Future<String> getTargetAudioPath(String meetingId, {String ext = 'm4a'}) async {
    final dir = await getAudioDirectory();
    final cleanExt = ext.startsWith('.') ? ext.substring(1) : ext;
    return '${dir.path}/meeting_$meetingId.$cleanExt';
  }

  /// Persistently save a recorded or picked audio file into NoteAX local storage
  static Future<String> persistMeetingAudio(String meetingId, String sourcePath) async {
    try {
      final sourceFile = File(sourcePath);
      if (!sourceFile.existsSync()) return sourcePath;

      final ext = sourcePath.split('.').last.toLowerCase();
      final targetPath = await getTargetAudioPath(meetingId, ext: ext);

      if (sourcePath != targetPath) {
        await sourceFile.copy(targetPath);
        debugPrint('[LocalAudio] Copied audio permanently to: $targetPath');
      }
      return targetPath;
    } catch (e) {
      debugPrint('[LocalAudio] Error persisting audio: $e');
      return sourcePath;
    }
  }

  /// Find local audio file for a given meeting ID
  static Future<String?> getLocalAudioPath(String meetingId) async {
    try {
      final dir = await getAudioDirectory();
      if (dir.existsSync()) {
        final files = dir.listSync();
        for (final file in files) {
          if (file is File && file.path.contains('meeting_$meetingId.')) {
            return file.path;
          }
        }
      }

      // Fallback check in parent documents directory for legacy names
      final docsDir = await getApplicationDocumentsDirectory();
      final parentFiles = docsDir.listSync();
      for (final file in parentFiles) {
        if (file is File && file.path.contains('recording_$meetingId')) {
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('[LocalAudio] Error searching local audio: $e');
    }
    return null;
  }

  /// Delete local audio file for a meeting
  static Future<void> deleteMeetingAudio(String meetingId) async {
    try {
      final path = await getLocalAudioPath(meetingId);
      if (path != null && File(path).existsSync()) {
        await File(path).delete();
        debugPrint('[LocalAudio] Deleted local audio for meeting $meetingId');
      }
    } catch (e) {
      debugPrint('[LocalAudio] Error deleting audio: $e');
    }
  }
}
