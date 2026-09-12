import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/meeting_model.dart';
import '../repositories/meeting_repository.dart';

class MeetingState {
  final bool isLoading;
  final List<Meeting> meetings;
  final Meeting? selectedMeeting;
  final String? errorMessage;

  const MeetingState({
    this.isLoading = false,
    this.meetings = const [],
    this.selectedMeeting,
    this.errorMessage,
  });

  MeetingState copyWith({
    bool? isLoading,
    List<Meeting>? meetings,
    Meeting? selectedMeeting,
    String? errorMessage,
  }) {
    return MeetingState(
      isLoading: isLoading ?? this.isLoading,
      meetings: meetings ?? this.meetings,
      selectedMeeting: selectedMeeting ?? this.selectedMeeting,
      errorMessage: errorMessage,
    );
  }
}

class MeetingController extends StateNotifier<MeetingState> {
  final MeetingRepository _repository;

  MeetingController(this._repository) : super(const MeetingState()) {
    fetchMeetings();
  }

  Future<void> fetchMeetings() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final meetings = await _repository.getMeetings();
      state = state.copyWith(isLoading: false, meetings: meetings);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  Future<Meeting?> createMeeting({
    required String title,
    required String meetingType,
    required DateTime dateTime,
    String? location,
    List<String>? participants,
    String? agenda,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final newMeeting = await _repository.createMeeting(
        title: title,
        meetingType: meetingType,
        dateTime: dateTime,
        location: location,
        participants: participants,
        agenda: agenda,
      );
      state = state.copyWith(
        isLoading: false,
        meetings: [newMeeting, ...state.meetings],
        selectedMeeting: newMeeting,
      );
      return newMeeting;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  Future<void> deleteMeeting(String id) async {
    try {
      await _repository.deleteMeeting(id);
      state = state.copyWith(
        meetings: state.meetings.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }
}

final meetingRepositoryProvider = Provider<MeetingRepository>((ref) {
  return MeetingRepository();
});

final meetingControllerProvider =
    StateNotifierProvider<MeetingController, MeetingState>((ref) {
  final repository = ref.watch(meetingRepositoryProvider);
  return MeetingController(repository);
});
