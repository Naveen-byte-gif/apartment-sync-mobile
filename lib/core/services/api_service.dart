import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

class ApiService {
  static String? _token;

  /// Request timeout so UI doesn't hang when backend is slow
  static const Duration requestTimeout = Duration(seconds: 30);

  static Future<void> init() async {
    _token = StorageService.getString(AppConstants.tokenKey);
  }

  static void setToken(String? token) {
    _token = token;
    print('🔑 [API] Token ${token != null ? "set" : "removed"}');
    if (token != null) {
      StorageService.setString(AppConstants.tokenKey, token);
    } else {
      StorageService.remove(AppConstants.tokenKey);
    }
  }

  static String? get token => _token;

  static void _log(String message, [String? body]) {
    if (kDebugMode) {
      if (body != null && body.length > 800) {
        print('$message (body length: ${body.length})');
      } else {
        print(body != null ? '$message $body' : message);
      }
    }
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    _log('📡 [API] GET: $url');

    final response = await http
        .get(url, headers: ApiConstants.getHeaders(_token))
        .timeout(requestTimeout, onTimeout: () {
      throw Exception('Request timed out. Please check your connection.');
    });

    _log('📡 [API] GET ${response.statusCode}', response.body);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    _log('📡 [API] POST: $url');

    final response = await http
        .post(
          url,
          headers: ApiConstants.getHeaders(_token),
          body: jsonEncode(data),
        )
        .timeout(requestTimeout, onTimeout: () {
      throw Exception('Request timed out. Please check your connection.');
    });

    _log('📡 [API] POST ${response.statusCode}', response.body);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    _log('📡 [API] PUT: $url');

    final response = await http
        .put(
          url,
          headers: ApiConstants.getHeaders(_token),
          body: jsonEncode(data),
        )
        .timeout(requestTimeout, onTimeout: () {
      throw Exception('Request timed out. Please check your connection.');
    });

    _log('📡 [API] PUT ${response.statusCode}', response.body);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    _log('📡 [API] DELETE: $url');

    final response = await http
        .delete(url, headers: ApiConstants.getHeaders(_token))
        .timeout(requestTimeout, onTimeout: () {
      throw Exception('Request timed out. Please check your connection.');
    });

    _log('📡 [API] DELETE ${response.statusCode}', response.body);
    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    File file, {
    String fieldName = 'image',
    Map<String, String>? additionalFields,
  }) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('📡 [API] UPLOAD Request: $url');

    final request = http.MultipartRequest('POST', url);

    // Add headers
    final headers = <String, String>{
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
    request.headers.addAll(headers);

    // Add additional fields if provided
    if (additionalFields != null) {
      request.fields.addAll(additionalFields);
    }

    // Add file
    final fileStream = http.ByteStream(file.openRead());
    final fileLength = await file.length();
    final multipartFile = http.MultipartFile(
      fieldName,
      fileStream,
      fileLength,
      filename: file.path.split('/').last,
      contentType: MediaType('image', 'jpeg'), // Default, can be improved
    );
    request.files.add(multipartFile);

    print('📡 [API] Uploading file: ${file.path}');

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('📡 [API] UPLOAD Response Status: ${response.statusCode}');
    print('📡 [API] UPLOAD Response Body: ${response.body}');

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(http.Response response) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Add status code to response for better error handling
      data['_statusCode'] = response.statusCode;

      // Always return the response data, let the caller handle success/error
      // This allows proper handling of {"success": false, "message": "..."} responses
      return data;
    } catch (e) {
      if (kDebugMode) print('❌ [API] Parse Error: $e');
      // Return error response in expected format
      return {
        'success': false,
        'message': 'Failed to parse response: ${e.toString()}',
        'error': e.toString(),
        '_statusCode': response.statusCode,
      };
    }
  }
}
