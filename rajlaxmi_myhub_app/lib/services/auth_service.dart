import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  final baseUrl = "http://192.168.1.17:8000"; // Your backend URL
  String? authToken;

  // =======================


  // Register
  // =======================
  Future<String> register(String name, String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      authToken = data['token'];
      return "Registration successful";
    } else {
      return "Error: ${response.body}";
    }
  }

  // =======================
  // Login
  // =======================
  Future<String> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login/'),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      authToken = data['token'];
      return "Login successful";
    } else {
      return "Invalid credentials";
    }
  }
}
