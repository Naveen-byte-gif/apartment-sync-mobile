import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../constants/api_constants.dart';
import 'storage_service.dart';
import '../constants/app_constants.dart';

class ApiService {
  static String? _token;

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

  static Future<Map<String, dynamic>> get(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('📡 [API] GET Request: $url');
    print('📡 [API] Headers: ${ApiConstants.getHeaders(_token)}');

    final response = await http.get(
      url,
      headers: ApiConstants.getHeaders(_token),
    );

    print('📡 [API] GET Response Status: ${response.statusCode}');
    print('📡 [API] GET Response Body: ${response.body}');

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('📡 [API] POST Request: $url');
    print('📡 [API] POST Headers: ${ApiConstants.getHeaders(_token)}');
    print('📡 [API] POST Body: ${jsonEncode(data)}');

    final response = await http.post(
      url,
      headers: ApiConstants.getHeaders(_token),
      body: jsonEncode(data),
    );

    print('📡 [API] POST Response Status: ${response.statusCode}');
    print('📡 [API] POST Response Body: ${response.body}');

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('📡 [API] PUT Request: $url');
    print('📡 [API] PUT Headers: ${ApiConstants.getHeaders(_token)}');
    print('📡 [API] PUT Body: ${jsonEncode(data)}');

    final response = await http.put(
      url,
      headers: ApiConstants.getHeaders(_token),
      body: jsonEncode(data),
    );

    print('📡 [API] PUT Response Status: ${response.statusCode}');
    print('📡 [API] PUT Response Body: ${response.body}');

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final url = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    print('📡 [API] DELETE Request: $url');
    print('📡 [API] DELETE Headers: ${ApiConstants.getHeaders(_token)}');

    final response = await http.delete(
      url,
      headers: ApiConstants.getHeaders(_token),
    );

    print('📡 [API] DELETE Response Status: ${response.statusCode}');
    print('📡 [API] DELETE Response Body: ${response.body}');

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
      print('📡 [API] Parsing response...');
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      print('📡 [API] Parsed Data: ${jsonEncode(data)}');

      // Add status code to response for better error handling
      data['_statusCode'] = response.statusCode;

      // Always return the response data, let the caller handle success/error
      // This allows proper handling of {"success": false, "message": "..."} responses
      return data;
    } catch (e) {
      print('❌ [API] Parse Error: $e');
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
