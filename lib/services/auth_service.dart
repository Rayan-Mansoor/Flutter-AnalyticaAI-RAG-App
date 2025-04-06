import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:analytica_ai/models/User.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';

class ApiClient extends http.BaseClient {
  final http.Client _inner;
  final String _apiKey;

  ApiClient(this._apiKey, [http.Client? client])
      : _inner = client ?? http.Client();

  bool _shouldSkipAuth(Uri url) {
    return url.path.contains('/login') || url.path.contains('/register');
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Add the API key to all requests.
    request.headers['X-API-Key'] = _apiKey;
    
    // For non-multipart requests, always set Content-Type to application/json.
    if (request is! http.MultipartRequest) {
      request.headers['Content-Type'] = 'application/json';
    }

    // If the endpoint is not exempt and no Authorization header exists,
    // inject the bearer token.
    if (!_shouldSkipAuth(request.url)) {
      final token = await AuthService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }
    
    return _inner.send(request);
  }

}


class AuthService {
  static final _storage = FlutterSecureStorage();
  static const _tokenKey = 'jwt_token';
  static const _userInfoKey = 'user_info';

  // Define base URL for API requests.
  static const String _baseUrl = 'http://192.168.0.101:8000/api/v1';
  static const String _apiKey = '123'; // Replace with your actual API key.
  static User? currentUser;

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


  static Future<bool> isTokenValid() async {
    final token = await getToken();
    if (token == null || JwtDecoder.isExpired(token)) {
      currentUser = null;
      return false;
    }
    // Only load user info once.
    if (currentUser == null) {
      await loadUserInfo();
    }
    return currentUser != null;
  }

  static Future<void> logout() async {
      await deleteToken();
      await clearUserInfo();
    }

  static Future<User?> saveUserInfo(String userName, String orgName, String role) async {
    final prefs = await SharedPreferences.getInstance();
    final userData = jsonEncode({
      'userName': userName,
      'orgName': orgName,
      'role': role,
    });
    await prefs.setString(_userInfoKey, userData);
    currentUser = User(userName: userName, orgName: orgName, role: role);
    return currentUser;
  }

  static Future<User?> loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final userInfoJson = prefs.getString(_userInfoKey);
    if (userInfoJson == null) return null;
    final userInfo = jsonDecode(userInfoJson);
    currentUser = User(
      userName: userInfo['userName'],
      orgName: userInfo['orgName'],
      role: userInfo['role'],
    );
    return currentUser;
  }

  /// **Clear user info**
  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userInfoKey);
    currentUser = null;
  }

  // Call the login API.
  static Future<bool> login(String email, String password) async {
    final url = Uri.parse('$_baseUrl/login');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({'email': email, 'password': password})
      );
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        String? token = responseData['access_token'];
        String? username = responseData['user_name'];
        String? orgName = responseData['org_name'];

        if (token != null && username != null && orgName != null) {
          await saveToken(token);

          // Decode JWT to extract role
          final decodedToken = JwtDecoder.decode(token);
          String role = decodedToken['role'] ?? 'member';

          await saveUserInfo(username, orgName, role);
          return true;
        }
        print('Login failed with status: ${response.statusCode}');
      }
        return false;
    } catch (e) {
      print('Error during login: $e');
      return false;
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

  // Fetch the conversations from the API.
  static Future<List<dynamic>?> fetchConversations() async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/get-conversations');
    try {
      final response = await _client.get(url);
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
    final endpoint = sessionId != null ? '/query/$sessionId' : '/query';
    final url = Uri.parse('$_baseUrl$endpoint');
    try {
      final body = jsonEncode({'text': text});
      final response = await _client.post(
        url,
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
    final url = Uri.parse('$_baseUrl/conversation-messages/$sessionId');
    try {
      final response = await _client.get(url);
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
    final url = Uri.parse('$_baseUrl/generate-report/$requestId');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body); // Expecting a JSON object with an "html" and "chart_images" field.
      } else {
        print('Generate report failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during generate report: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> updateStructuredReport(String originalHtml, String? generalInstruction, List<Map<String, dynamic>>? specificInstructions) async {
    final url = Uri.parse('$_baseUrl/update_strutured_report');
    final body = jsonEncode({
      "originalHtml": originalHtml,
      "generalInstruction": generalInstruction,
      "specificInstructions": specificInstructions,
    });
    try {
      final response = await _client.post(
        url,
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
    final url = Uri.parse('$_baseUrl/get_pdf_report');
    
    // Send a POST request with the HTML content in the body.
    final response = await _client.post(
      url,
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

  static Future<Map<String, dynamic>?> getCompanyHealth() async {
    final url = Uri.parse('$_baseUrl/get-company-health');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('getCompanyHealth failed with status: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error during getCompanyHealth: $e');
      return null;
    }
  }

  // Get all users (excluding the admin)
  static Future<List<dynamic>?> getUsers() async {
    final url = Uri.parse('$_baseUrl/get-users');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        // Decode the response and filter out the admin user if needed.
        List<dynamic> users = jsonDecode(response.body);
        // Optionally filter out the admin user from the list.
        users = users.where((user) => user['role'] != 'admin').toList();
        return users;
      } else {
        print("getUsers failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during getUsers: $e");
      return null;
    }
  }

  // Create a new user
  static Future<Map<String, dynamic>?> createUser(String name, String email, String password, String role) async {
    final url = Uri.parse('$_baseUrl/create-user');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'name': name,
          'email': email,
          'password': password,
          'role': role,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print("createUser failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during createUser: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getSqlDatabase() async {
    final token = await getToken();
    if (token == null) return null;
    final url = Uri.parse('$_baseUrl/get-sql-database');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("getSqlDatabase failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during getSqlDatabase: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> setSqlDatabase(Map<String, dynamic> payload) async {
    final url = Uri.parse('$_baseUrl/set-sql-database');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("setSqlDatabase failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during setSqlDatabase: $e");
      return null;
    }
  }

  /// Fetches all table access levels.
  static Future<List<dynamic>?> getTablesAccessLevels() async {
    final url = Uri.parse('$_baseUrl/get-table-access-level');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        print("getTablesAccessLevels failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during getTablesAccessLevels: $e");
      return null;
    }
  }

  /// Updates the access level of a specific table.
  static Future<Map<String, dynamic>?> updateTableAccessLevel(String tableName, String accessLevel) async {
    final url = Uri.parse('$_baseUrl/update-table-access-level');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'table_name': tableName,
          'access_level': accessLevel,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("updateTableAccessLevel failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during updateTableAccessLevel: $e");
      return null;
    }
  }

  static Future<List<dynamic>?> getDocumentAccessLevels() async {
    final url = Uri.parse('$_baseUrl/get-document-access-level');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as List<dynamic>;
      } else {
        print("getDocumentAccessLevels failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during getDocumentAccessLevels: $e");
      return null;
    }
  }

  /// Updates the access level of a document.
  static Future<Map<String, dynamic>?> updateDocumentAccessLevel(String docId, String accessLevel) async {
    final url = Uri.parse('$_baseUrl/update-document-access-level');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode({
          'doc_id': docId,
          'access_level': accessLevel,
        }),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("updateDocumentAccessLevel failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during updateDocumentAccessLevel: $e");
      return null;
    }
  }

  /// Processes (uploads) a PDF file for processing.
  static Future<Map<String, dynamic>?> processPdf(File pdfFile, bool premiumMode) async {
    final url = Uri.parse('$_baseUrl/process-pdf');
    
    try {
      // Create a multipart request
      var request = http.MultipartRequest('POST', url);
            
      // Add the PDF file
      request.files.add(
        await http.MultipartFile.fromPath(
          'pdf',
          pdfFile.path,
          contentType: MediaType('application', 'pdf'),
        ),
      );
      
      // Add the premium_mode parameter as a form field
      request.fields['premium_mode'] = premiumMode.toString();
      
      // Send the request using your ApiClient
      var streamedResponse = await _client.send(request);
      
      // Get the response
      var response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("processPdf failed with status: ${response.statusCode}, message: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Error during processPdf: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> processWebsite(String urls, bool headless) async {
    final url = Uri.parse('$_baseUrl/process-website');
    final payload = jsonEncode({"urls": [urls], "headless": headless});

    print("Sending request to $url with payload: $payload"); // Debugging log

    try {
      final response = await _client.post(
        url,
        body: payload,
      );

      print("Response: ${response.statusCode} - ${response.body}"); // Debugging log

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("processWebsite failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during processWebsite: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> setLLMApiKey(Map<String, dynamic> payload) async {
    final url = Uri.parse('$_baseUrl/set-llm-api-key');
    try {
      final response = await _client.post(
        url,
        body: jsonEncode(payload),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("setLLMApiKey failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during setLLMApiKey: $e");
      return null;
    }
  }

  // New method to get the existing LLM configuration.
  static Future<Map<String, dynamic>?> getLLMApiKey() async {
    final url = Uri.parse('$_baseUrl/get-llm-api-key');
    try {
      final response = await _client.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("getLLMApiKey failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error during getLLMApiKey: $e");
      return null;
    }
  }


}
