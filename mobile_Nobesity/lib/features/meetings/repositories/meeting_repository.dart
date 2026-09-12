import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/meeting_model.dart';

class MeetingRepository {
  final ApiClient _apiClient;

  MeetingRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<List<Meeting>> getMeetings({String? status, String? meetingType}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (meetingType != null && meetingType.isNotEmpty) {
        queryParams['meetingType'] = meetingType;
      }

      final response = await _apiClient.dio.get(
        ApiConstants.meetings,
        queryParameters: queryParams,
      );

      if (response.data['success'] == true) {
        final List list = response.data['data']['meetings'] ?? [];
        return list.map((item) => Meeting.fromJson(item)).toList();
      }
      return [];
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to load meetings';
      throw Exception(errorMsg);
    }
  }

  Future<Meeting> getMeetingById(String id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.meetings}/$id');
      if (response.data['success'] == true) {
        return Meeting.fromJson(response.data['data']['meeting']);
      }
      throw Exception('Meeting not found');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to load meeting details';
      throw Exception(errorMsg);
    }
  }

  Future<Map<String, dynamic>> getMeetingWithRelations(String id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.meetings}/$id');
      if (response.data['success'] == true) {
        final data = response.data['data'];
        return {
          'meeting': Meeting.fromJson(data['meeting']),
          'transcript': data['transcript'],
          'mom': data['mom'],
          'documents': data['documents'],
          'processingJob': data['processingJob'],
        };
      }
      throw Exception('Failed to load meeting details');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to load meeting details';
      throw Exception(errorMsg);
    }
  }

  Future<Meeting> createMeeting({
    required String title,
    required String meetingType,
    required DateTime dateTime,
    String? location,
    List<String>? participants,
    String? agenda,
  }) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.meetings,
        data: {
          'title': title,
          'meetingType': meetingType,
          'dateTime': dateTime.toIso8601String(),
          'location': location ?? '',
          'participants': participants ?? [],
          'agenda': agenda ?? '',
        },
      );

      if (response.data['success'] == true) {
        return Meeting.fromJson(response.data['data']['meeting']);
      }
      throw Exception(response.data['error'] ?? 'Failed to create meeting');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to create meeting';
      throw Exception(errorMsg);
    }
  }

  Future<Meeting> updateMeeting({
    required String id,
    String? title,
    String? meetingType,
    DateTime? dateTime,
    String? location,
    List<String>? participants,
    String? agenda,
    String? status,
    int? duration,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (meetingType != null) data['meetingType'] = meetingType;
      if (dateTime != null) data['dateTime'] = dateTime.toIso8601String();
      if (location != null) data['location'] = location;
      if (participants != null) data['participants'] = participants;
      if (agenda != null) data['agenda'] = agenda;
      if (status != null) data['status'] = status;
      if (duration != null) data['duration'] = duration;

      final response = await _apiClient.dio.put(
        '${ApiConstants.meetings}/$id',
        data: data,
      );

      if (response.data['success'] == true) {
        return Meeting.fromJson(response.data['data']['meeting']);
      }
      throw Exception('Failed to update meeting');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to update meeting';
      throw Exception(errorMsg);
    }
  }

  Future<void> deleteMeeting(String id) async {
    try {
      await _apiClient.dio.delete('${ApiConstants.meetings}/$id');
    } on DioException catch (e) {
      final errorMsg = e.response?.data?['error'] ??
          e.message ??
          'Failed to delete meeting';
      throw Exception(errorMsg);
    }
  }
}
