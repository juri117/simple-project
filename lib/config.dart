import 'dart:convert';
import 'package:flutter/services.dart';

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
      print('Config: Successfully loaded config.json');
      print('Config: Backend URL = ${_config['backend']['url']}');
    } catch (e) {
      // Fallback configuration for web deployment issues
      print(
          'Warning: Failed to load config.json, using fallback configuration: $e');
      _config = {
        'backend': {'url': 'http://sp-be.diaven.de'}
      };
      print(
          'Config: Using fallback backend URL = ${_config['backend']['url']}');
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
    print('Config: Building URL for endpoint "$endpoint" -> "$url"');

    return url;
  }

  // Future extensibility - add more config getters as needed
  // Example:
  // int get timeoutSeconds => _config['timeout'] ?? 30;
  // String get apiVersion => _config['api_version'] ?? 'v1';
}
