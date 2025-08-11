import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config.dart';

class HttpService {
  static final HttpService _instance = HttpService._internal();
  factory HttpService() => _instance;
  HttpService._internal();

  Map<String, String> _getAuthHeaders() {
    final session = UserSession.instance;
    final headers = {
      'Content-Type': 'application/json',
    };

    if (session.sessionToken != null) {
      headers['Authorization'] = 'Bearer ${session.sessionToken}';
    }

    return headers;
  }

  Future<http.Response> get(String url) async {
    return await http.get(
      Uri.parse(url),
      headers: _getAuthHeaders(),
    );
  }

  Future<http.Response> post(String url, {Object? body}) async {
    return await http.post(
      Uri.parse(url),
      headers: _getAuthHeaders(),
      body: body != null ? json.encode(body) : null,
    );
  }

  Future<http.Response> put(String url, {Object? body}) async {
    return await http.put(
      Uri.parse(url),
      headers: _getAuthHeaders(),
      body: body != null ? json.encode(body) : null,
    );
  }

  Future<http.Response> delete(String url, {Object? body}) async {
    return await http.delete(
      Uri.parse(url),
      headers: _getAuthHeaders(),
      body: body != null ? json.encode(body) : null,
    );
  }

  // Helper method to handle authentication errors
  Future<bool> handleAuthError(http.Response response) async {
    if (response.statusCode == 401) {
      // Clear user session on authentication error
      await UserSession.instance.clearUser();
      return true; // Indicates auth error was handled
    }
    return false; // No auth error
  }
}
