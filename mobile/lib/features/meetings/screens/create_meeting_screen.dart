import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../controllers/meeting_controller.dart';
import 'meeting_details_screen.dart';

class CreateMeetingScreen extends ConsumerStatefulWidget {
  const CreateMeetingScreen({super.key});

  @override
  ConsumerState<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends ConsumerState<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _participantController = TextEditingController();
  final _agendaController = TextEditingController();

  String _selectedMeetingType = 'Project Review';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _participants = [];

  final List<String> _meetingTypes = [
    'Team Meeting',
    'Project Review',
    'Client Meeting',
    'Planning Meeting',
    'General Meeting',
    'Custom',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _participantController.dispose();
    _agendaController.dispose();
    super.dispose();
  }

  void _addParticipant() {
    final text = _participantController.text.trim();
    if (text.isNotEmpty && !_participants.contains(text)) {
      setState(() {
        _participants.add(text);
        _participantController.clear();
      });
    }
  }

  void _removeParticipant(String name) {
    setState(() {
      _participants.remove(name);
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final fullDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final created = await ref.read(meetingControllerProvider.notifier).createMeeting(
          title: _titleController.text.trim(),
          meetingType: _selectedMeetingType,
          dateTime: fullDateTime,
          location: _locationController.text.trim(),
          participants: _participants,
          agenda: _agendaController.text.trim(),
        );

    if (created != null && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => MeetingDetailsScreen(meetingId: created.id),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final meetingState = ref.watch(meetingControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Meeting'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Meeting Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title *',
                    hintText: 'e.g., Sprint Planning Q3',
                    prefixIcon: Icon(Icons.title_outlined),
                  ),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                ),
                const SizedBox(height: 16),

                // Meeting Type Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _selectedMeetingType,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Type',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _meetingTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedMeetingType = val);
                  },
                ),
                const SizedBox(height: 16),

                // Date & Time Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Date',
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          child: Text(
                            DateFormat('dd MMM yyyy').format(_selectedDate),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Time',
                            prefixIcon: Icon(Icons.access_time_outlined),
                          ),
                          child: Text(_selectedTime.format(context)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Location Field
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location / Room',
                    hintText: 'e.g., Conference Room B / Google Meet',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Participants Field with Add Button
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _participantController,
                        decoration: const InputDecoration(
                          labelText: 'Participants',
                          hintText: 'Add name & tap +',
                          prefixIcon: Icon(Icons.people_outline),
                        ),
                        onSubmitted: (_) => _addParticipant(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _addParticipant,
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                if (_participants.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _participants
                        .map(
                          (name) => Chip(
                            label: Text(name),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeParticipant(name),
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 16),

                // Agenda Field
                TextFormField(
                  controller: _agendaController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Agenda / Description',
                    hintText: 'Outline main objectives or topics...',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 28),

                // Submit Button
                ElevatedButton(
                  onPressed: meetingState.isLoading ? null : _handleSave,
                  child: meetingState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create & Continue'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
