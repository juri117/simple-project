import 'dart:convert';
import 'package:flutter/services.dart';

class UserSession {
  static UserSession? _instance;
  static UserSession get instance {
    _instance ??= UserSession._internal();
    return _instance!;
  }

  UserSession._internal();

  int? _userId;
  String? _username;
  String? _sessionToken;
  String? _userRole;

  void setUser(int userId, String username, String sessionToken,
      {String? role}) {
    _userId = userId;
    _username = username;
    _sessionToken = sessionToken;
    _userRole = role ?? 'normal';
  }

  void clearUser() {
    _userId = null;
    _username = null;
    _sessionToken = null;
    _userRole = null;
  }

  int? get userId => _userId;
  String? get username => _username;
  String? get sessionToken => _sessionToken;
  String? get userRole => _userRole;
  bool get isLoggedIn {
    final loggedIn =
        _userId != null && _username != null && _sessionToken != null;
    return loggedIn;
  }
}

class Config {
  static Config? _instance;
  static Config get instance {
    _instance ??= Config._internal();
    return _instance!;
  }

  Config._internal();

  late Map<String, dynamic> _config;

  Future<void> load() async {
    try {
      final String configString =
          await rootBundle.loadString('assets/config.json');
      _config = json.decode(configString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback configuration for web deployment issues
      _config = {
        'backend': {'url': 'http://sp-be.diaven.de'}
      };
    }
  }

  String get backendUrl {
    final backend = _config['backend'] as Map<String, dynamic>;
    final url = backend['url'] as String;
    return url;
  }

  String get backendBaseUrl => backendUrl;

  // Helper method to build full API endpoint URLs
  String buildApiUrl(String endpoint) {
    // Ensure the backend URL doesn't end with a slash
    final baseUrl = backendBaseUrl.endsWith('/')
        ? backendBaseUrl.substring(0, backendBaseUrl.length - 1)
        : backendBaseUrl;

    // Ensure the endpoint doesn't start with a slash
    final cleanEndpoint =
        endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;

    // Build the URL
    final url = '$baseUrl/$cleanEndpoint';

    return url;
  }

  // Future extensibility - add more config getters as needed
  // Example:
  // int get timeoutSeconds => _config['timeout'] ?? 30;
  // String get apiVersion => _config['api_version'] ?? 'v1';
}
