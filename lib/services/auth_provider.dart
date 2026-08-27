import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

class AuthProvider extends ChangeNotifier {
  String? token;
  int? userId;
  String? userNome;
  String? userColore;
  bool? isAdmin;
  String? userEmail;

  bool get isAuthenticated => token != null;

  Future<void> ripristinaSessione() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    userId = prefs.getInt('userId');
    userNome = prefs.getString('userNome');
    userColore = prefs.getString('userColore');
    isAdmin = prefs.getBool('isAdmin');
    userEmail = prefs.getString('userEmail');
    apiClient.setToken(token);
    notifyListeners();
  }

  Future<void> login(String email, String password, {bool ricordami = false}) async {
    final result = await apiClient.post('/auth/login', body: {
      'email': email,
      'password': password,
    });
    token = result['token'] as String;
    final user = result['user'] as Map<String, dynamic>;
    userId = user['id'] as int;
    userNome = user['nome'] as String;
    userColore = user['colore'] as String? ?? '#3B82F6';
    isAdmin = user['isAdmin'] as bool? ?? false;
    userEmail = user['email'] as String?;

    apiClient.setToken(token);

    if (ricordami) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token!);
      await prefs.setInt('userId', userId!);
      await prefs.setString('userNome', userNome!);
      await prefs.setString('userColore', userColore!);
      await prefs.setBool('isAdmin', isAdmin!);
      if (userEmail != null) await prefs.setString('userEmail', userEmail!);
    }

    notifyListeners();
  }

  Future<void> logout() async {
    token = null;
    userId = null;
    userNome = null;
    userColore = null;
    isAdmin = null;
    userEmail = null;
    apiClient.setToken(null);

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    notifyListeners();
  }
}
