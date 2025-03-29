import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient extends http.BaseClient {
  final http.Client _inner;
  final String _apiKey;

  ApiClient(this._apiKey, [http.Client? client])
      : _inner = client ?? http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    // Add common headers to all requests.
    request.headers['X-API-Key'] = _apiKey;
    request.headers['Content-Type'] = 'application/json';
    return _inner.send(request);
  }
}

class AuthService {
  static final _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';

  // Define base URL for API requests.
  static const String _baseUrl = 'http://192.168.0.101:10000/api/v1';
  static const String _apiKey = '123'; // Replace with your actual API key.

  // Instantiate the custom API client.
  static final ApiClient _client = ApiClient(_apiKey);

  // Save the token securely.
  static Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  // Retrieve the token.
  static Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  // Delete the token (logout).
  static Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // Call the login API.
  static Future<Map<String, dynamic>?> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'email': email, 'password': password}),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Login failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during login: $e');
      return null;
    }
  }

  // Call the signup API.
  static Future<Map<String, dynamic>?> signup(String orgName, String name, String email, String password) async {
    final url = Uri.parse('$_baseUrl/register');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'org_name': orgName,
          'admin_name': name,
          'admin_email': email,
          'admin_password': password,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print('Signup failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during signup: $e');
      return null;
    }
  }

  // Validate the stored token by calling a backend endpoint.
  static Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null) return false;
    final url = Uri.parse('$_baseUrl/validate');
    try {
      // Note: This endpoint might require different headers; adjust as needed.
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error during token validation: $e');
      return false;
    }
  }

  // Fetch the conversations from the API.
  static Future<List<dynamic>?> fetchConversations() async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/get-conversations');
    try {
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        // Assuming the API returns a JSON array of conversation objects.
        List<dynamic> conversations = jsonDecode(response.body);
        return conversations;
      } else {
        print("Failed to load conversations: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during conversation fetch: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> query(String text, {String? sessionId}) async {
    final token = await getToken();
    if (token == null) return null;
    final endpoint = sessionId != null ? '/query/$sessionId' : '/query';
    final url = Uri.parse('$_baseUrl$endpoint');
    try {
      final body = jsonEncode({'text': text});
      final response = await _client.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
        body: body,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Query failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during query: $e');
      return null;
    }
  }

    static Future<List<dynamic>?> fetchConversationHistory(String sessionId) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/conversation-messages/$sessionId');
    try {
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        // Assuming the API returns an object with a "messages" key.
        final data = jsonDecode(response.body);
        return data['messages'] as List<dynamic>;
      } else {
        print("Failed to load conversation history: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during conversation history fetch: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> generateReport(String requestId) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/generate-report/$requestId');
    try {
      final response = await _client.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Expecting a JSON object with an "html" field.
      } else {
        print('Generate report failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during generate report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateStructuredReport(
      String originalHtml,
      String? generalInstruction,
      List<Map<String, dynamic>>? specificInstructions) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/update_strutured_report');
    final body = jsonEncode({
      "originalHtml": originalHtml,
      "generalInstruction": generalInstruction,
      "specificInstructions": specificInstructions,
    });
    try {
      final response = await _client.post(
        url,
        headers: {'Authorization': 'Bearer $token'},
        body: body,
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Update report failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error updating report: $e');
      return null;
    }
  }

    static Future<Uint8List?> downloadPdfReport(String htmlContent) async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/get_pdf_report');
    
    // Send a POST request with the HTML content in the body.
    final response = await _client.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
      body: jsonEncode({'html': htmlContent}),
    );
    
    if (response.statusCode == 200) {
      // Return the PDF as bytes.
      return response.bodyBytes;
    } else {
      print('Download PDF failed with status: ${response.statusCode}');
      return null;
    }
  }
}
