import 'package:http/http.dart' as http;
import 'dart:convert';
import '../lib/config.dart';

class HttpTest {
  static Future<void> testAuthHeader() async {
    try {
      final url = Config.instance.buildApiUrl('test_auth_header.php');
      print('Testing auth header with URL: $url');

      // Test without auth header first
      final response1 = await http.get(Uri.parse(url));
      print('Response without auth: ${response1.statusCode}');
      print('Response body: ${response1.body}');

      // Test with auth header
      final response2 = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test-token-123'
        },
      );
      print('Response with auth: ${response2.statusCode}');
      print('Response body: ${response2.body}');
    } catch (e) {
      print('Test failed: $e');
    }
  }
}
