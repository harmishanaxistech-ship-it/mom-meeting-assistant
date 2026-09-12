import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService _storageService;

  ApiClient({SecureStorageService? storageService})
      : _storageService = storageService ?? SecureStorageService() {
    dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(minutes: 15), // Extended to 15 minutes for large recordings
        sendTimeout: const Duration(minutes: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storageService.getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['X-Company-Code'] = ApiConstants.companyCode;
        options.headers['Authorization'] = 'Bearer $token';
          }
          print('\n🚀 [HTTP Request] ────────────────────────────');
          print('URL: [${options.method}] ${options.uri}');
          print('Headers: ${options.headers}');
          if (options.data is FormData) {
            final formData = options.data as FormData;
            final fields = formData.fields.map((e) => '${e.key}: ${e.value}').toList();
            final files = formData.files.map((e) => '${e.key}: ${e.value.filename} (${e.value.length} bytes)').toList();
            print('FormData Fields: $fields');
            print('FormData Files: $files');
          } else if (options.data != null) {
            print('Body: ${options.data}');
          }
          if (options.queryParameters.isNotEmpty) {
            print('Query: ${options.queryParameters}');
          }
          print('────────────────────────────────────────────\n');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          print('\n✅ [HTTP Response] ───────────────────────────');
          print('Status: ${response.statusCode} | URL: [${response.requestOptions.method}] ${response.requestOptions.uri}');
          print('Data: ${response.data}');
          print('────────────────────────────────────────────\n');
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          print('\n❌ [HTTP Error] ─────────────────────────────');
          print('Status: ${error.response?.statusCode}');
          print('URL: [${error.requestOptions.method}] ${error.requestOptions.uri}');
          print('Message: ${error.message}');
          if (error.response?.data != null) {
            print('Response Body: ${error.response?.data}');
          }
          print('────────────────────────────────────────────\n');
          return handler.next(error);
        },
      ),
    );
  }
}
