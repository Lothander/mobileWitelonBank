import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/saved_recipient.dart';

class RecipientService {
  final String _apiBaseUrl;
  final String? _token;

  RecipientService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  Future<List<SavedRecipient>> getSavedRecipients() async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }
    final uri = Uri.parse('$_apiBaseUrl/zapisani-odbiorcy');

    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decodedResponse = jsonDecode(response.body);

        List<dynamic> recipientsData;
        if (decodedResponse is Map<String, dynamic> &&
            decodedResponse.containsKey('data') &&
            decodedResponse['data'] is List) {
          recipientsData = decodedResponse['data'] as List<dynamic>;
        } else if (decodedResponse is List) {
          recipientsData = decodedResponse;
        } else {
          throw Exception('Nieoczekiwana struktura odpowiedzi od serwera.');
        }
        return recipientsData
            .map((recipientJson) =>
            SavedRecipient.fromJson(recipientJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Nie udało się pobrać zapisanych odbiorców. Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Błąd pobierania zapisanych odbiorców: ${e.toString()}');
    }
  }

  Future<SavedRecipient> addSavedRecipient(
      SavedRecipient recipientData) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }
    final uri = Uri.parse('$_apiBaseUrl/zapisani-odbiorcy');
    final body = jsonEncode(recipientData.toJson());

    try {
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 201) {
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('data') &&
            responseData['data'] is Map) {
          return SavedRecipient.fromJson(
              responseData['data'] as Map<String, dynamic>);
        } else if (responseData is Map<String, dynamic>) {
          return SavedRecipient.fromJson(responseData);
        } else {
          throw Exception(
              'Nieoczekiwana struktura odpowiedzi po dodaniu odbiorcy.');
        }
      } else {
        String errorMessage = "Błąd dodawania odbiorcy.";
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('message')) {
          errorMessage = responseData['message'] as String;
          if (response.statusCode == 422 &&
              responseData.containsKey('errors')) {
            final errors = responseData['errors'] as Map<String, dynamic>;
            errors.forEach((key, value) {
              if (value is List && value.isNotEmpty) {
                errorMessage += "\n${key.replaceAll('_', ' ')}: ${value.join(', ')}";
              }
            });
          }
        }
        throw Exception('$errorMessage Kod: ${response.statusCode}.');
      }
    } catch (e) {
      throw Exception('Błąd dodawania zapisanego odbiorcy: ${e.toString()}');
    }
  }

  Future<SavedRecipient> updateSavedRecipient(
      int recipientId, SavedRecipient recipientData) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }
    final uri = Uri.parse('$_apiBaseUrl/zapisani-odbiorcy/$recipientId');
    final body = jsonEncode(recipientData.toJson());

    try {
      final response = await http.put(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));

      final responseData = jsonDecode(response.body);
      if (response.statusCode == 200) {
        if (responseData is Map<String, dynamic>) {
          return SavedRecipient.fromJson(responseData);
        } else {
          throw Exception(
              'Nieoczekiwana struktura odpowiedzi po aktualizacji odbiorcy.');
        }
      } else {
        String errorMessage = "Błąd aktualizacji odbiorcy.";
        if (responseData is Map<String, dynamic> &&
            responseData.containsKey('message')) {
          errorMessage = responseData['message'] as String;
        }
        throw Exception('$errorMessage Kod: ${response.statusCode}.');
      }
    } catch (e) {
      throw Exception('Błąd aktualizacji zapisanego odbiorcy: ${e.toString()}');
    }
  }

  Future<void> deleteSavedRecipient(int recipientId) async {
    if (_token == null) {
      throw Exception('Brak autoryzacji.');
    }
    final uri = Uri.parse('$_apiBaseUrl/zapisani-odbiorcy/$recipientId');

    try {
      final response = await http.delete(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 204 || response.statusCode == 200) {
        return;
      } else {
        String errorMessage = "Błąd usuwania odbiorcy.";
        try {
          if (response.body.isNotEmpty) {
            final responseData = jsonDecode(response.body);
            if (responseData is Map<String, dynamic> &&
                responseData.containsKey('message')) {
              errorMessage = responseData['message'] as String;
            }
          }
        } catch (_) {}
        throw Exception('$errorMessage Kod: ${response.statusCode}.');
      }
    } catch (e) {
      throw Exception('Błąd usuwania zapisanego odbiorcy: ${e.toString()}');
    }
  }
}