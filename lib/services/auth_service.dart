import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class User {
  final int id;
  final String name;
  final String surname;
  final String email;
  final bool isAdmin;

  User({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.isAdmin,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      name: json['imie'] as String,
      surname: json['nazwisko'] as String,
      email: json['email'] as String,
      isAdmin: json['administrator'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'imie': name,
      'nazwisko': surname,
      'email': email,
      'administrator': isAdmin,
    };
  }
}

enum LoginStep1ResultStatus {
  success,
  invalidCredentials,
  validationError,
  serverError,
  networkError,
}

class LoginStep1Result {
  final LoginStep1ResultStatus status;
  final String? message;
  final String? email;

  LoginStep1Result({required this.status, this.message, this.email});
}

class AuthService with ChangeNotifier {
  User? _currentUser;
  String? _token;
  final _storage = const FlutterSecureStorage();

  static const String apiBaseUrl = 'https://witelonapi.host358482.xce.pl/api';

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isAuthenticated => _token != null && _currentUser != null;

  AuthService() {
    _tryAutoLogin();
  }

  Future<void> _tryAutoLogin() async {
    final storedToken = await _storage.read(key: 'authToken');
    final storedUserJson = await _storage.read(key: 'currentUser');

    if (storedToken != null && storedUserJson != null) {
      try {
        _token = storedToken;
        _currentUser =
            User.fromJson(jsonDecode(storedUserJson) as Map<String, dynamic>);
        notifyListeners();
      } catch (e) {
        await _clearAuthData();
      }
    }
  }

  Future<LoginStep1Result> loginStep1Request2FACode(
      String email, String password) async {
    final url = Uri.parse('$apiBaseUrl/login');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'haslo': password,
        }),
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final message = responseData['message'] as String?;

      if (response.statusCode == 200) {
        final responseEmail = responseData['email'] as String?;
        return LoginStep1Result(
            status: LoginStep1ResultStatus.success,
            message: message,
            email: responseEmail ?? email);
      } else if (response.statusCode == 401) {
        return LoginStep1Result(
            status: LoginStep1ResultStatus.invalidCredentials,
            message: message ?? 'Nieprawidłowy email lub hasło.');
      } else if (response.statusCode == 422) {
        return LoginStep1Result(
            status: LoginStep1ResultStatus.validationError,
            message: message ?? 'Błąd walidacji danych.');
      } else if (response.statusCode == 500) {
        return LoginStep1Result(
            status: LoginStep1ResultStatus.serverError,
            message: message ?? 'Błąd serwera. Spróbuj ponownie później.');
      } else {
        return LoginStep1Result(
            status: LoginStep1ResultStatus.networkError,
            message: 'Nieoczekiwany błąd: ${response.statusCode}');
      }
    } on TimeoutException {
      return LoginStep1Result(
          status: LoginStep1ResultStatus.networkError,
          message:
          'Serwer nie odpowiedział w wyznaczonym czasie. Sprawdź połączenie.');
    } catch (error) {
      return LoginStep1Result(
          status: LoginStep1ResultStatus.networkError,
          message: 'Błąd połączenia. Sprawdź internet.');
    }
  }

  Future<bool> loginStep2Verify2FACode(
      String email, String verificationCode) async {
    final url = Uri.parse('$apiBaseUrl/2fa');
    final requestBody = {
      'email': email,
      'dwuetapowy_kod': verificationCode.trim(),
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;
        if (responseData.containsKey('token') &&
            responseData.containsKey('user')) {
          _token = responseData['token'] as String?;
          final userData = responseData['user'] as Map<String, dynamic>?;

          if (_token != null && userData != null) {
            _currentUser = User.fromJson(userData);
            await _storage.write(key: 'authToken', value: _token);
            await _storage.write(
                key: 'currentUser', value: jsonEncode(_currentUser!.toJson()));
            notifyListeners();
            return true;
          }
        }
        await _clearAuthData();
        return false;
      } else {
        await _clearAuthData();
        return false;
      }
    } on TimeoutException {
      return false;
    } catch (error) {
      await _clearAuthData();
      return false;
    }
  }

  Future<void> logout() async {
    if (_token != null) {
      final url = Uri.parse('$apiBaseUrl/logout');
      try {
        await http.post(
          url,
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
        ).timeout(const Duration(seconds: 10));
      } catch (error) {
        // Ignorujemy błędy przy wylogowywaniu,
        // ponieważ dane lokalne zostaną i tak usunięte.
      }
    }
    await _clearAuthData();
    notifyListeners();
  }

  Future<void> _clearAuthData() async {
    _currentUser = null;
    _token = null;
    await _storage.delete(key: 'authToken');
    await _storage.delete(key: 'currentUser');
  }

  Future<String> requestPasswordReset(String email) async {
    final url = Uri.parse('$apiBaseUrl/forgot-password');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'email': email}),
      ).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);
      final message = responseData['message'] as String?;

      if (response.statusCode == 200) {
        return message ??
            'Jeśli użytkownik istnieje, link do resetowania hasła został wysłany.';
      } else if (response.statusCode == 422) {
        return message ?? 'Podany adres email jest nieprawidłowy.';
      } else if (response.statusCode == 500) {
        return message ?? 'Wystąpił błąd serwera. Spróbuj ponownie później.';
      } else {
        return message ??
            'Nie udało się wysłać żądania resetowania hasła. Kod: ${response.statusCode}';
      }
    } on TimeoutException {
      return 'Serwer nie odpowiedział w wyznaczonym czasie. Spróbuj ponownie.';
    } catch (error) {
      return 'Wystąpił błąd sieciowy. Spróbuj ponownie.';
    }
  }
}