import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('Starting HTTP request...');
  try {
    final response = await http.post(
      Uri.parse('https://demo2.rce-eastjava.org/api/login'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'email': 'test@example.com',
        'password': 'password',
      }),
    ).timeout(const Duration(seconds: 10));

    print('Status Code: ${response.statusCode}');
    print('Response Body: ${response.body}');
  } catch (e, stackTrace) {
    print('Exception caught: $e');
    print('Stack trace: $stackTrace');
  }
}
