import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:mobile_witelon_bank/models/standing_order.dart';

class StandingOrderService {
  final String _apiBaseUrl;
  final String? _token;

  StandingOrderService({required String apiBaseUrl, required String? token})
      : _apiBaseUrl = apiBaseUrl,
        _token = token;

  Future<List<StandingOrder>> getStandingOrders() async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale');

    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final List<dynamic> responseData =
        jsonDecode(response.body) as List<dynamic>;
        return responseData
            .map((orderJson) =>
            StandingOrder.fromJson(orderJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(
            'Nie udało się pobrać zleceń stałych. Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Błąd pobierania zleceń stałych: ${e.toString()}');
    }
  }

  Future<StandingOrder> createStandingOrder(StandingOrder orderData) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale');
    final body = jsonEncode(orderData.toJsonForCreate());

    try {
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        return StandingOrder.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        String errorMessage = 'Nie udało się utworzyć zlecenia stałego.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          }
        } catch (_) {}
        throw Exception('$errorMessage Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Błąd tworzenia zlecenia stałego: ${e.toString()}');
    }
  }

  Future<StandingOrder> updateStandingOrder(
      int orderId, StandingOrder orderData) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale/$orderId');
    final body = jsonEncode(orderData.toJsonForUpdate());

    try {
      final response = await http.put(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return StandingOrder.fromJson(
            jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        String errorMessage = 'Nie udało się zaktualizować zlecenia stałego.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          }
        } catch (_) {}
        throw Exception('$errorMessage Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Błąd aktualizacji zlecenia stałego: ${e.toString()}');
    }
  }

  Future<void> deleteStandingOrder(int orderId) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale/$orderId');

    try {
      final response = await http.delete(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        String errorMessage = 'Nie udało się usunąć zlecenia stałego.';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic> &&
              errorData.containsKey('message')) {
            errorMessage = errorData['message'] as String;
          }
        } catch (_) {}
        throw Exception('$errorMessage Kod: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception(
          'Błąd usuwania/dezaktywacji zlecenia stałego: ${e.toString()}');
    }
  }
}