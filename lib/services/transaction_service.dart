import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/models/transfer_request_data.dart';

class TransactionService {
  final String _apiBaseUrl;
  final String? _token;

  TransactionService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  Future<List<Transaction>> getTransactionHistory(int accountId,
      {int page = 1, int perPage = 15, String? type}) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }

    Map<String, String> queryParams = {
      'strona': page.toString(),
      'na_strone': perPage.toString(),
    };
    if (type != null && type.isNotEmpty) {
      queryParams['typ'] = type;
    }

    final uri = Uri.parse('$_apiBaseUrl/konta/$accountId/przelewy')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> decodedResponse =
        jsonDecode(response.body) as Map<String, dynamic>;
        if (decodedResponse.containsKey('data') &&
            decodedResponse['data'] is List) {
          final List<dynamic> transactionsData =
          decodedResponse['data'] as List<dynamic>;
          return transactionsData
              .map((transactionJson) =>
              Transaction.fromJson(transactionJson as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception('Nieoczekiwana struktura odpowiedzi od serwera.');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Sesja wygasła lub błąd autoryzacji (401).');
      } else if (response.statusCode == 403) {
        throw Exception('Brak uprawnień do tego konta (403).');
      } else if (response.statusCode == 404) {
        throw Exception('Konto nie znalezione (404).');
      } else {
        throw Exception(
            'Nie udało się pobrać historii transakcji. Kod: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception(
          'Serwer nie odpowiedział w wyznaczonym czasie. Sprawdź połączenie.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Wystąpił błąd podczas pobierania historii transakcji.');
    }
  }

  Future<Transaction> makeTransfer(TransferRequestData transferData) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }

    final url = Uri.parse('$_apiBaseUrl/przelewy');
    final requestBodyJson = jsonEncode(transferData.toJson());

    try {
      final response = await http
          .post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Accept': 'application/json',
          'Authorization': 'Bearer $_token',
        },
        body: requestBodyJson,
      )
          .timeout(const Duration(seconds: 20));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 201) {
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data') &&
            responseData['data'] is Map) {
          return Transaction.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else if (responseData is Map<String, dynamic>) {
          return Transaction.fromJson(responseData);
        } else {
          throw Exception(
              'Nieoczekiwana struktura odpowiedzi po utworzeniu przelewu.');
        }
      } else {
        String apiMessage = "Nieznany błąd API.";
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('message')) {
          apiMessage = responseData['message'] as String;
          if (response.statusCode == 422 &&
              responseData.containsKey('errors')) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                String formattedKey = key.replaceAll('_', ' ');
                formattedKey =
                    formattedKey[0].toUpperCase() + formattedKey.substring(1);
                apiMessage += "\n$formattedKey: ${value.join(', ')}";
              }
            });
          }
        }
        throw Exception(apiMessage);
      }
    } on TimeoutException {
      throw Exception(
          'Serwer nie odpowiedział w wyznaczonym czasie. Spróbuj ponownie.');
    } catch (e) {
      if (e is Exception && e.toString().contains("Nieznany błąd API")) {
        rethrow;
      }
      throw Exception(
          'Wystąpił błąd podczas wykonywania przelewu. Szczegóły: ${e.toString()}');
    }
  }

  Future<Uint8List> exportTransactionHistoryToPdf({
    required int accountId,
    required String dateFrom,
    required String dateTo,
    String? type,
  }) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }

    Map<String, String> queryParams = {
      'data_od': dateFrom,
      'data_do': dateTo,
    };
    if (type != null && type.isNotEmpty) {
      queryParams['typ'] = type;
    }

    final uri = Uri.parse('$_apiBaseUrl/konta/$accountId/przelewy/export')
        .replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/pdf',
          'Authorization': 'Bearer $_token',
        },
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        String? contentType = response.headers['content-type'];
        if (contentType != null &&
            contentType.toLowerCase().contains('application/pdf')) {
          return response.bodyBytes;
        } else {
          throw Exception(
              "Serwer zwrócił nieoczekiwany format danych zamiast pliku PDF.");
        }
      } else {
        String errorMessage = 'Nie udało się wyeksportować historii (PDF).';
        try {
          if (response.body.isNotEmpty) {
            final errorData = jsonDecode(response.body);
            if (errorData is Map<String, dynamic> &&
                errorData.containsKey('message')) {
              errorMessage = errorData['message'] as String;
            } else if (response.body.length < 200) {
              errorMessage += ' Odpowiedź serwera: ${response.body}';
            }
          }
        } catch (_) {
          if (response.body.isNotEmpty && response.body.length < 200) {
            errorMessage += ' Odpowiedź serwera: ${response.body}';
          }
        }
        throw Exception('$errorMessage (Kod: ${response.statusCode})');
      }
    } on TimeoutException {
      throw Exception('Serwer nie odpowiedział w wyznaczonym czasie.');
    } catch (e) {
      throw Exception('Błąd podczas eksportu historii (PDF): ${e.toString()}');
    }
  }
}