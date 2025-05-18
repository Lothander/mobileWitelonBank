import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/bank_account.dart';

class AccountService {
  final String _apiBaseUrl;
  final String? _token;

  AccountService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  Future<List<BankAccount>> getAccounts() async {
    if (_token == null) {
      print("DEBUG: AccountService - Token is null. Cannot fetch accounts.");
      throw Exception('Brak autoryzacji. Zaloguj się ponownie.');
    }

    final url = Uri.parse('$_apiBaseUrl/konta');
    print("DEBUG: AccountService - Attempting GET to $url");

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 15));

      print("DEBUG: AccountService - Response from /konta! Status: ${response.statusCode}");
      print("DEBUG: AccountService - Response body from /konta: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body) as List<dynamic>;
        return responseData
            .map((accountJson) => BankAccount.fromJson(accountJson as Map<String, dynamic>))
            .toList();
      } else if (response.statusCode == 401) {
        throw Exception('Sesja wygasła lub błąd autoryzacji (401).');
      } else {
        throw Exception('Nie udało się pobrać danych konta. Kod: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Błąd w AccountService.getAccounts: TimeoutException - $e');
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie. Sprawdź połączenie.');
    } catch (error) {
      print('Błąd sieciowy w AccountService.getAccounts: $error');
      throw Exception('Wystąpił błąd sieciowy podczas pobierania danych konta.');
    }
  }
}