import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:smartcook/config/api_config.dart';
import 'package:smartcook/service/token_service.dart';

class ApiService {
  static String get _baseUrl => ApiConfig.baseUrl;
  static String get _apiKey => ApiConfig.apiKey;

  static void Function()? onUnauthorized;

  static Future<Map<String, String>> _headers({bool useAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'x-api-key': _apiKey,
    };
    if (useAuth) {
      final token = await TokenService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  static Future<ApiResponse> _handleResponse(http.Response res) async {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(res.body);
    } catch (e) {
      final preview = res.body.length > 200 
          ? '${res.body.substring(0, 200)}...' 
          : res.body;
      return ApiResponse(
        success: false,
        message: 'Format respons tidak valid: $preview',
        statusCode: res.statusCode,
      );
    }
    if (res.statusCode == 401) {
      await TokenService.clearAll();
      onUnauthorized?.call();
      final msg = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Sesi habis, silakan login lagi';
      return ApiResponse(success: false, message: msg, statusCode: 401);
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      // Backend mungkin mengembalikan data langsung atau dalam wrapper
      dynamic responseData = body;
      if (body is Map) {
        // Cek apakah ada wrapper 'data' atau langsung di root
        responseData = body.containsKey('data') ? body['data'] : body;
      }
      return ApiResponse(
        success: true,
        data: responseData,
        message: body is Map && body['message'] != null
            ? body['message'].toString()
            : null,
        statusCode: res.statusCode,
      );
    }
    final message = body is Map && body['message'] != null
        ? body['message'].toString()
        : 'Terjadi kesalahan (${res.statusCode})';
    return ApiResponse(
      success: false,
      data: body is Map ? body['data'] : null,
      message: message,
      statusCode: res.statusCode,
    );
  }

  static Future<ApiResponse> get(
    String path, {
    Map<String, String>? queryParameters,
    bool useAuth = true,
  }) async {
    try {
      var uri = Uri.parse('$_baseUrl$path');
      if (queryParameters != null && queryParameters.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParameters);
      }
      final res = await http
          .get(uri, headers: await _headers(useAuth: useAuth))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(res);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Periksa koneksi internet',
      );
    }
  }

  static Future<ApiResponse> post(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = false,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = await _headers(useAuth: useAuth);
      final bodyStr = body != null ? jsonEncode(body) : null;
      if (kDebugMode) {
        debugPrint('POST $uri');
        debugPrint('Headers: $headers');
        debugPrint('Body: $bodyStr');
      }
      final res = await http
          .post(
            uri,
            headers: headers,
            body: bodyStr,
          )
          .timeout(const Duration(seconds: 30));
      if (kDebugMode) {
        debugPrint('Response status: ${res.statusCode}');
        debugPrint('Response body: ${res.body}');
      }
      return _handleResponse(res);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Periksa koneksi internet: ${e.toString()}',
      );
    }
  }

  static Future<ApiResponse> put(
    String path, {
    Map<String, dynamic>? body,
    bool useAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await http
          .put(
            uri,
            headers: await _headers(useAuth: useAuth),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 30));
      return _handleResponse(res);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Periksa koneksi internet',
      );
    }
  }

  static Future<ApiResponse> delete(
    String path, {
    bool useAuth = true,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final res = await http
          .delete(uri, headers: await _headers(useAuth: useAuth))
          .timeout(const Duration(seconds: 30));
      return _handleResponse(res);
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Periksa koneksi internet',
      );
    }
  }
}

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });
}
