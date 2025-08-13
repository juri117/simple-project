import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _isInitialized = false;

  // Initialize session from persistent storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');
      final username = prefs.getString('username');
      final sessionToken = prefs.getString('session_token');
      final userRole = prefs.getString('user_role');

      if (userId != null && username != null && sessionToken != null) {
        _userId = userId;
        _username = username;
        _sessionToken = sessionToken;
        _userRole = userRole ?? 'normal';
      }
    } catch (e) {
      // Error loading user session: $e
    }

    _isInitialized = true;
  }

  Future<void> setUser(int userId, String username, String sessionToken,
      {String? role}) async {
    _userId = userId;
    _username = username;
    _sessionToken = sessionToken;
    _userRole = role ?? 'normal';

    // Save to persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);
      await prefs.setString('username', username);
      await prefs.setString('session_token', sessionToken);
      await prefs.setString('user_role', _userRole!);
    } catch (e) {
      // Error saving user session: $e
    }
  }

  Future<void> clearUser() async {
    _userId = null;
    _username = null;
    _sessionToken = null;
    _userRole = null;

    // Clear from persistent storage
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      await prefs.remove('username');
      await prefs.remove('session_token');
      await prefs.remove('user_role');
    } catch (e) {
      // Error clearing user session: $e
    }
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

  // Check if session is initialized
  bool get isInitialized => _isInitialized;
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
      String configString;

      // First, try to load from project root (for deployment overrides)
      try {
        final file = File('config.json');
        if (await file.exists()) {
          configString = await file.readAsString();
          // Loaded config from project root: config.json
        } else {
          // Fallback to bundled asset if root file doesn't exist
          configString = await rootBundle.loadString('assets/config.json');
          // Loaded config from bundled asset: assets/config.json
        }
      } catch (e) {
        // If file system access fails (e.g., in web), fallback to bundled asset
        configString = await rootBundle.loadString('assets/config.json');
        // Fallback to bundled asset due to error: $e
      }

      _config = json.decode(configString) as Map<String, dynamic>;
    } catch (e) {
      // Final fallback configuration
      // Using fallback configuration due to error: $e
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

  String get baseUrl {
    return _config['base_url'] as String? ?? 'http://localhost:8080';
  }

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

// Responsive design constants
class ResponsiveBreakpoints {
  /// Breakpoint for switching between mobile and desktop layouts
  ///
  /// - Below this width: Mobile layout (drawer menu)
  /// - Above this width: Desktop layout (sidebar)
  ///
  /// Common values to experiment with:
  /// - 600: Mobile-first approach
  /// - 768: Tablet/desktop (current default)
  /// - 900: Desktop-focused
  /// - 1024: Large desktop
  static const double mobileBreakpoint = 1201.0; //768
}
