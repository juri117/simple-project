import 'package:http/http.dart' as http;
import 'package:simple_project/config.dart';

class HttpTest {
  static Future<void> testAuthHeader() async {
    try {
      final url = Config.instance.buildApiUrl('test_auth_header.php');

      // Test without auth header first
      await http.get(Uri.parse(url));

      // Test with auth header
      await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer test-token-123'
        },
      );
    } catch (e) {
      // Test failed
    }
  }
}
