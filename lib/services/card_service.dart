import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/payment_card.dart';

class CardService {
  final String _apiBaseUrl;
  final String? _token;

  CardService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  Future<List<PaymentCard>> getCardsForAccount(int accountId) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/konta/$accountId/karty');
    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> responseData =
        jsonDecode(response.body) as List<dynamic>;
        return responseData
            .map((cardJson) =>
            PaymentCard.fromJson(cardJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Nie udało się pobrać kart. Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Błąd pobierania kart: ${e.toString()}');
    }
  }

  PaymentCard _parseCardUpdateResponse(http.Response response) {
    final responseBody = response.body;
    if (response.statusCode == 200) {
      final decodedResponse =
      jsonDecode(responseBody) as Map<String, dynamic>;
      if (decodedResponse.containsKey('data') &&
          decodedResponse['data'] is Map) {
        return PaymentCard.fromJson(
            decodedResponse['data'] as Map<String, dynamic>);
      } else {
        throw Exception('Nieoczekiwana odpowiedź serwera po aktualizacji karty.');
      }
    } else {
      String errorMessage =
          'Operacja na karcie nie powiodła się. Kod: ${response.statusCode}';
      try {
        final errorData = jsonDecode(responseBody) as Map<String, dynamic>;
        if (errorData.containsKey('message')) {
          errorMessage = errorData['message'] as String;
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  Future<PaymentCard> blockCard(int cardId) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/karty/$cardId/zablokuj');
    try {
      final response = await http.patch(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 10));
      return _parseCardUpdateResponse(response);
    } catch (e) {
      throw Exception('Błąd blokowania karty: ${e.toString()}');
    }
  }

  Future<PaymentCard> unblockCard(int cardId) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/karty/$cardId/odblokuj');
    try {
      final response = await http.patch(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 10));
      return _parseCardUpdateResponse(response);
    } catch (e) {
      throw Exception('Błąd odblokowywania karty: ${e.toString()}');
    }
  }

  Future<PaymentCard> changeDailyLimit(int cardId, double newLimit) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/karty/$cardId/limit');
    final body = jsonEncode({'limit_dzienny': newLimit});
    try {
      final response = await http.patch(uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: body).timeout(const Duration(seconds: 10));
      return _parseCardUpdateResponse(response);
    } catch (e) {
      throw Exception('Błąd zmiany limitu karty: ${e.toString()}');
    }
  }

  Future<PaymentCard> updatePaymentSettings(int cardId,
      {bool? internetPayments, bool? contactlessPayments}) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/karty/$cardId/ustawienia-platnosci');
    Map<String, bool> bodyMap = {};
    if (internetPayments != null) {
      bodyMap['platnosci_internetowe_aktywne'] = internetPayments;
    }
    if (contactlessPayments != null) {
      bodyMap['platnosci_zblizeniowe_aktywne'] = contactlessPayments;
    }
    if (bodyMap.isEmpty) {
      throw Exception("Nie podano żadnych ustawień płatności do zmiany.");
    }
    final body = jsonEncode(bodyMap);
    try {
      final response = await http.patch(uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $_token',
          },
          body: body).timeout(const Duration(seconds: 10));
      return _parseCardUpdateResponse(response);
    } catch (e) {
      throw Exception('Błąd zmiany ustawień płatności: ${e.toString()}');
    }
  }
}