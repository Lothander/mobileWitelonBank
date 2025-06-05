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
    print("DEBUG: StandingOrderService - GET $uri");

    try {
      final response = await http.get(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));
      print("DEBUG: StandingOrderService.getStandingOrders - Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 200) {
        final List<dynamic> responseData = jsonDecode(response.body) as List<dynamic>;
        return responseData
            .map((orderJson) => StandingOrder.fromJson(orderJson as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception('Nie udało się pobrać zleceń stałych. Kod: ${response.statusCode}');
      }
    } catch (e, s) {
      print("DEBUG: StandingOrderService.getStandingOrders - Error: $e, Stack: $s");
      throw Exception('Błąd pobierania zleceń stałych: ${e.toString()}');
    }
  }

  Future<StandingOrder> createStandingOrder(StandingOrder orderData) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale');
    final body = jsonEncode(orderData.toJsonForCreate());
    print("DEBUG: StandingOrderService - POST $uri with body $body");

    try {
      final response = await http.post(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));
      print("DEBUG: StandingOrderService.createStandingOrder - Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 201) {
        return StandingOrder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        // TODO: Lepsza obsługa błędów walidacji z API (jeśli zwraca szczegóły)
        throw Exception('Nie udało się utworzyć zlecenia stałego. Kod: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e, s) {
      print("DEBUG: StandingOrderService.createStandingOrder - Error: $e, Stack: $s");
      throw Exception('Błąd tworzenia zlecenia stałego: ${e.toString()}');
    }
  }

  Future<StandingOrder> updateStandingOrder(int orderId, StandingOrder orderData) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale/$orderId');
    final body = jsonEncode(orderData.toJsonForUpdate());
    print("DEBUG: StandingOrderService - PUT $uri with body $body");

    try {
      final response = await http.put(uri, headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }, body: body).timeout(const Duration(seconds: 15));
      print("DEBUG: StandingOrderService.updateStandingOrder - Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 200) {
        return StandingOrder.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      } else {
        // TODO: Lepsza obsługa błędów
        throw Exception('Nie udało się zaktualizować zlecenia stałego. Kod: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e, s) {
      print("DEBUG: StandingOrderService.updateStandingOrder - Error: $e, Stack: $s");
      throw Exception('Błąd aktualizacji zlecenia stałego: ${e.toString()}');
    }
  }

  Future<void> deleteStandingOrder(int orderId) async {
    if (_token == null) throw Exception('Brak autoryzacji.');
    final uri = Uri.parse('$_apiBaseUrl/zlecenia-stale/$orderId');
    print("DEBUG: StandingOrderService - DELETE $uri");

    try {
      final response = await http.delete(uri, headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $_token',
      }).timeout(const Duration(seconds: 15));
      print("DEBUG: StandingOrderService.deleteStandingOrder - Status: ${response.statusCode}, Body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 204) {
        return;
      } else {
        // TODO: Lepsza obsługa błędów
        throw Exception('Nie udało się usunąć/dezaktywować zlecenia stałego. Kod: ${response.statusCode}. Body: ${response.body}');
      }
    } catch (e, s) {
      print("DEBUG: StandingOrderService.deleteStandingOrder - Error: $e, Stack: $s");
      throw Exception('Błąd usuwania/dezaktywacji zlecenia stałego: ${e.toString()}');
    }
  }
}