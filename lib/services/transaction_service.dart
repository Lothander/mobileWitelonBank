// lib/services/transaction_service.dart
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

  Future<List<Transaction>> getTransactionHistory(int accountId, {int page = 1, int perPage = 15, String? type}) async {
    if (_token == null) {
      print("DEBUG: TransactionService.getTransactionHistory - Token is null. Cannot fetch transactions.");
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
    print("DEBUG: TransactionService.getTransactionHistory - Attempting GET to $uri");

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 20));

      print("DEBUG: TransactionService.getTransactionHistory - Response from /konta/$accountId/przelewy! Status: ${response.statusCode}");
      print("DEBUG: TransactionService.getTransactionHistory - Response body: ${response.body}");


      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse = jsonDecode(response.body) as Map<String, dynamic>;
        if (decodedResponse.containsKey('data') && decodedResponse['data'] is List) {
          final List<dynamic> transactionsData = decodedResponse['data'] as List<dynamic>;
          return transactionsData
              .map((transactionJson) => Transaction.fromJson(transactionJson as Map<String, dynamic>))
              .toList();
        } else {
          print("DEBUG: TransactionService.getTransactionHistory - Unexpected response structure. 'data' key missing or not a list.");
          throw Exception('Nieoczekiwana struktura odpowiedzi od serwera.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Sesja wygasła lub błąd autoryzacji (401).');
      } else if (response.statusCode == 403) {
        throw Exception('Brak uprawnień do tego konta (403).');
      } else if (response.statusCode == 404) {
        throw Exception('Konto nie znalezione (404).');
      } else {
        print("DEBUG: TransactionService.getTransactionHistory - Server error: ${response.statusCode}, Body: ${response.body}");
        throw Exception('Nie udało się pobrać historii transakcji. Kod: ${response.statusCode}');
      }
    } on TimeoutException catch (e) {
      print('DEBUG: TransactionService.getTransactionHistory - TimeoutException: $e');
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie. Sprawdź połączenie.');
    } catch (error, stackTrace) { // Dodano stackTrace dla lepszego debugowania
      print('DEBUG: TransactionService.getTransactionHistory - CatchAll Error: $error');
      print('DEBUG: TransactionService.getTransactionHistory - StackTrace: $stackTrace');
      if (error is Exception) rethrow;
      throw Exception('Wystąpił błąd podczas pobierania historii transakcji.');
    }
  }

  Future<Transaction> makeTransfer(TransferRequestData transferData) async {
    if (_token == null) {
      print("DEBUG: TransactionService.makeTransfer - Token is null. Cannot make transfer.");
      throw Exception('Brak autoryzacji. Zaloguj się ponownie.');
    }

    final url = Uri.parse('$_apiBaseUrl/przelewy');
    final requestBodyJson = jsonEncode(transferData.toJson());

    print("DEBUG: TransactionService.makeTransfer - Attempting POST to $url");
    print("DEBUG: TransactionService.makeTransfer - Request body for /przelewy: $requestBodyJson");

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

      print("DEBUG: TransactionService.makeTransfer - Response from /przelewy! Status: ${response.statusCode}");
      print("DEBUG: TransactionService.makeTransfer - Response body from /przelewy: ${response.body}");

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // Odpowiedź API jest obiektem z kluczem "data", który zawiera obiekt transakcji
        if (responseData is Map<String, dynamic> && responseData.containsKey('data')) {
          final transactionJson = responseData['data'] as Map<String, dynamic>;
          // Teraz przekazujemy poprawny obiekt do Transaction.fromJson
          return Transaction.fromJson(transactionJson);
        } else {
          // Jeśli struktura odpowiedzi jest inna niż oczekiwana
          print("DEBUG: TransactionService.makeTransfer - Unexpected response structure for 201. 'data' key missing or not an object.");
          throw Exception('Nieoczekiwana struktura odpowiedzi po utworzeniu przelewu.');
        }
      } else {
        String apiMessage = "Nieznany błąd API.";
        String detailedErrors = "";

        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('message')) {
            apiMessage = responseData['message'] as String;
          }
          if (response.statusCode == 422 && responseData.containsKey('errors')) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                String formattedKey = key.replaceAll('_', ' ');
                formattedKey = formattedKey[0].toUpperCase() + formattedKey.substring(1);
                detailedErrors += "\n$formattedKey: ${value.join(', ')}";
              }
            });
            apiMessage += detailedErrors;
          }
        }

        print("DEBUG: TransactionService.makeTransfer - API Error (${response.statusCode}): $apiMessage. Full response: ${response.body}");
        throw Exception(apiMessage);
      }
    } on TimeoutException catch (e) {
      print('DEBUG: TransactionService.makeTransfer - TimeoutException: $e');
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie. Spróbuj ponownie.');
    } catch (error, stackTrace) {
      print('DEBUG: TransactionService.makeTransfer - CatchAll Error: $error');
      print('DEBUG: TransactionService.makeTransfer - StackTrace: $stackTrace');
      if (error is Exception && error.toString().contains("Nieznany błąd API")) {
        rethrow;
      }
      throw Exception('Wystąpił błąd podczas wykonywania przelewu. Szczegóły: ${error.toString()}');
    }
  }
}