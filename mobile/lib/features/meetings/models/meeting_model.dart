class Meeting {
  final String id;
  final String title;
  final String meetingType;
  final DateTime dateTime;
  final String location;
  final List<String> participants;
  final String agenda;
  final int duration; // in seconds
  final String status;
  final DateTime createdAt;
  final String? audioFileName;

  Meeting({
    required this.id,
    required this.title,
    required this.meetingType,
    required this.dateTime,
    required this.location,
    required this.participants,
    required this.agenda,
    required this.duration,
    required this.status,
    required this.createdAt,
    this.audioFileName,
  });

  factory Meeting.fromJson(Map<String, dynamic> json) {
    return Meeting(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? 'Untitled Meeting',
      meetingType: json['meetingType'] ?? 'General Meeting',
      dateTime: json['dateTime'] != null
          ? DateTime.tryParse(json['dateTime']) ?? DateTime.now()
          : DateTime.now(),
      location: json['location'] ?? '',
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      agenda: json['agenda'] ?? '',
      duration: json['duration'] ?? 0,
      status: json['status'] ?? 'created',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
      audioFileName: json['audioFile']?['filename'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'meetingType': meetingType,
      'dateTime': dateTime.toIso8601String(),
      'location': location,
      'participants': participants,
      'agenda': agenda,
      'duration': duration,
      'status': status,
    };
  }

  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
