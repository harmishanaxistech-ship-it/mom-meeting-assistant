import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/audio_player_widget.dart';
import '../controllers/meeting_controller.dart';
import '../models/meeting_model.dart';
import '../../recording/screens/recording_screen.dart';
import '../../mom/screens/mom_screen.dart';

class MeetingDetailsScreen extends ConsumerStatefulWidget {
  final String meetingId;

  const MeetingDetailsScreen({super.key, required this.meetingId});

  @override
  ConsumerState<MeetingDetailsScreen> createState() => _MeetingDetailsScreenState();
}

class _MeetingDetailsScreenState extends ConsumerState<MeetingDetailsScreen> {
  Meeting? _meeting;
  Map<String, dynamic>? _momData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      final repo = ref.read(meetingRepositoryProvider);
      final response = await repo.getMeetingWithRelations(widget.meetingId);
      if (mounted) {
        setState(() {
          _meeting = response['meeting'] as Meeting?;
          _momData = response['mom'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppTheme.accentColor;
      case 'transcribing':
      case 'analyzing':
      case 'mom_generated':
      case 'uploading':
        return Colors.orange;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return AppTheme.secondaryColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_meeting == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meeting Details')),
        body: const Center(child: Text('Meeting not found')),
      );
    }

    final meeting = _meeting!;

    return Scaffold(
      appBar: AppBar(
        title: Text(meeting.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchDetails,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Meeting?'),
                  content: const Text('This will delete all associated data permanently.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(meetingControllerProvider.notifier).deleteMeeting(meeting.id);
                if (context.mounted) Navigator.of(context).pop();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Type Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meeting.meetingType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy, hh:mm a').format(meeting.dateTime),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(meeting.status).withAlpha(25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getStatusColor(meeting.status).withAlpha(100),
                      ),
                    ),
                    child: Text(
                      meeting.status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(meeting.status),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Audio Player Section (Show meeting recorded audio)
            if (meeting.audioFileName != null && meeting.audioFileName!.isNotEmpty) ...[
              AudioPlayerWidget(
                audioUrl: '${ApiConstants.serverBaseUrl}/uploads/${meeting.audioFileName}',
                title: meeting.title,
              ),
              const SizedBox(height: 20),
            ],

            // Location
            if (meeting.location.isNotEmpty) ...[
              const Text(
                'Location',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(meeting.location, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 16),
            ],

            // Participants
            if (meeting.participants.isNotEmpty) ...[
              const Text(
                'Participants',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: meeting.participants
                    .map((p) => Chip(
                          avatar: const CircleAvatar(
                            backgroundColor: AppTheme.primaryColor,
                            child: Icon(Icons.person, size: 14, color: Colors.white),
                          ),
                          label: Text(p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],

            // Agenda
            if (meeting.agenda.isNotEmpty) ...[
              const Text(
                'Agenda',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(meeting.agenda, style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
            ],

            // View Generated MOM Button (when completed)
            if (meeting.status == 'completed' || _momData != null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MOMScreen(meetingId: meeting.id),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('View & Edit Generated MOM'),
              ),
              const SizedBox(height: 12),
            ],

            // Action Start/Re-record Meeting Button
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RecordingScreen(meeting: meeting),
                  ),
                ).then((_) => _fetchDetails());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: meeting.status == 'completed'
                    ? Colors.grey.shade800
                    : Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              icon: Icon(meeting.status == 'completed' ? Icons.replay : Icons.mic),
              label: Text(
                meeting.status == 'completed'
                    ? 'Re-record & Regenerate MOM'
                    : 'Start Recording Meeting',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
