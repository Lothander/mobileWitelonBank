import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/models/transfer_request_data.dart';

class TransactionService {
  final String _apiBaseUrl;
  final String? _token;

  TransactionService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  // Metoda do pobierania historii transakcji dla danego konta
  Future<List<Transaction>> getTransactionHistory(int accountId, {int page = 1, int perPage = 15, String? type}) async {
    if (_token == null) {
      print("DEBUG: TransactionService - Token is null. Cannot fetch transactions.");
      throw Exception('Brak autoryzacji. Zaloguj się ponownie.');
    }

    Map<String, String> queryParams = {
      'strona': page.toString(),
      'na_strone': perPage.toString(),
    };
    if (type != null && type.isNotEmpty) {
      queryParams['typ'] = type;
    }

    final uri = Uri.parse('$_apiBaseUrl/konta/$accountId/przelewy').replace(queryParameters: queryParams);
    print("DEBUG: TransactionService - Attempting GET to $uri");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 20));

      print("DEBUG: TransactionService - Response from /konta/$accountId/przelewy! Status: ${response.statusCode}");
      print("DEBUG: TransactionService - Response body: ${response.body}");

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (decodedResponse.containsKey('data') && decodedResponse['data'] is List) {
          final List<dynamic> transactionsData = decodedResponse['data'] as List<dynamic>;
          return transactionsData
              .map((transactionJson) => Transaction.fromJson(transactionJson as Map<String, dynamic>))
              .toList();
        } else {
          print("DEBUG: TransactionService - Unexpected response structure for transaction history. 'data' key missing or not a list.");
          throw Exception('Nieoczekiwana struktura odpowiedzi od serwera.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Sesja wygasła lub błąd autoryzacji (401).');
      } else if (response.statusCode == 403) {
        throw Exception('Brak uprawnień do tego konta (403).');
      } else if (response.statusCode == 404) {
        throw Exception('Konto nie znalezione (404).');
      } else {
        throw Exception('Nie udało się pobrać historii transakcji. Kod: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('Błąd w TransactionService.getTransactionHistory: TimeoutException - $e');
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie. Sprawdź połączenie.');
    } catch (error) {
      print('Błąd (sieciowy lub parsowania) w TransactionService.getTransactionHistory: $error');
      if (error is Exception) rethrow;
      throw Exception('Wystąpił błąd podczas pobierania historii transakcji.');
    }
  }

  // Metoda do wykonywania nowego przelewu
  Future<Transaction> makeTransfer(TransferRequestData transferData) async {
    if (_token == null) {
      print("DEBUG: TransactionService - Token is null. Cannot make transfer.");
      throw Exception('Brak autoryzacji. Zaloguj się ponownie.');
    }

    final url = Uri.parse('$_apiBaseUrl/przelewy');
    final requestBodyJson = jsonEncode(transferData.toJson());

    print("DEBUG: TransactionService - Attempting POST to $url");
    print("DEBUG: TransactionService - Request body for /przelewy: $requestBodyJson");

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: requestBodyJson,
      ).timeout(const Duration(seconds: 20));

      print("DEBUG: TransactionService - Response from /przelewy! Status: ${response.statusCode}");
      print("DEBUG: TransactionService - Response body: ${response.body}");

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return Transaction.fromJson(responseData as Map<String, dynamic>);
      } else {
        String errorMessage = "Wystąpił nieznany błąd podczas wykonywania przelewu.";
        if (responseData is Map<String, dynamic> && responseData.containsKey('message')) {
          errorMessage = responseData['message'] as String;
          if (response.statusCode == 422 && responseData.containsKey('errors')) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                String formattedKey = key.replaceAll('_', ' ');
                formattedKey = formattedKey[0].toUpperCase() + formattedKey.substring(1);
                errorMessage += "\n$formattedKey: ${value.join(', ')}";
              }
            });
          }
        }
        print("DEBUG: TransactionService - Transfer error (${response.statusCode}): $errorMessage. Full response: ${response.body}");
        throw Exception(errorMessage);
      }
    } on TimeoutException catch (e) {
      print('Błąd w TransactionService.makeTransfer: TimeoutException - $e');
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie. Spróbuj ponownie.');
    } catch (error) {
      print('Błąd (sieciowy lub parsowania) w TransactionService.makeTransfer: $error');
      if (error is Exception) rethrow;
      throw Exception('Wystąpił błąd podczas wykonywania przelewu.');
    }
  }
}