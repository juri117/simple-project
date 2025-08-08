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
      final String configString = await rootBundle.loadString('./config.json');
      _config = json.decode(configString) as Map<String, dynamic>;
    } catch (e) {
      // Fallback to default configuration if config file cannot be loaded
      print('Error loading config: $e');
      _config = {
        'backend': {
          'url': 'http://localhost',
          'port': 8000,
        }
      };
    }
  }

  String get backendUrl {
    final backend = _config['backend'] as Map<String, dynamic>;
    final url = backend['url'] as String;
    final port = backend['port'] as int;
    return '$url:$port';
  }

  String get backendBaseUrl => backendUrl;

  // Helper method to build full API endpoint URLs
  String buildApiUrl(String endpoint) {
    return '$backendBaseUrl/$endpoint';
  }

  // Future extensibility - add more config getters as needed
  // Example:
  // int get timeoutSeconds => _config['timeout'] ?? 30;
  // String get apiVersion => _config['api_version'] ?? 'v1';
}
