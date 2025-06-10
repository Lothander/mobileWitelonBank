import 'package:intl/intl.dart';

class StandingOrder {
  final int id;
  final int userId;
  final int sourceAccountId;
  final String targetAccountNumber;
  final String recipientName;
  final String transferTitle;
  final double amount;
  final String frequency;
  final DateTime startDate;
  final DateTime? nextExecutionDate;
  final DateTime? endDate;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  StandingOrder({
    required this.id,
    required this.userId,
    required this.sourceAccountId,
    required this.targetAccountNumber,
    required this.recipientName,
    required this.transferTitle,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.nextExecutionDate,
    this.endDate,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StandingOrder.fromJson(Map<String, dynamic> json) {
    DateTime? tryParseDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        return DateFormat('yyyy-MM-dd').parseStrict(dateString);
      } catch (e) {
        try {
          return DateTime.parse(dateString);
        } catch (_) {
          return null;
        }
      }
    }

    DateTime defaultDate = DateTime(1970);

    return StandingOrder(
      id: json['id'] as int? ?? 0,
      userId: json['id_uzytkownika'] as int? ?? 0,
      sourceAccountId: json['id_konta_zrodlowego'] as int? ?? 0,
      targetAccountNumber:
      json['nr_konta_docelowego'] as String? ?? 'Brak danych',
      recipientName: json['nazwa_odbiorcy'] as String? ?? 'Brak danych',
      transferTitle: json['tytul_przelewu'] as String? ?? 'Brak tytułu',
      amount: (json['kwota'] as num? ?? 0).toDouble(),
      frequency: json['czestotliwosc'] as String? ?? 'Nieznana',
      startDate: tryParseDate(json['data_startu'] as String?) ?? defaultDate,
      nextExecutionDate:
      tryParseDate(json['data_nastepnego_wykonania'] as String?),
      endDate: tryParseDate(json['data_zakonczenia'] as String?),
      isActive: json['aktywne'] as bool? ?? false,
      createdAt:
      DateTime.tryParse(json['created_at'] as String? ?? '') ?? defaultDate,
      updatedAt:
      DateTime.tryParse(json['updated_at'] as String? ?? '') ?? defaultDate,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return {
      'id_konta_zrodlowego': sourceAccountId,
      'nr_konta_docelowego': targetAccountNumber,
      'nazwa_odbiorcy': recipientName,
      'tytul_przelewu': transferTitle,
      'kwota': amount,
      'czestotliwosc': frequency,
      'data_startu': DateFormat('yyyy-MM-dd').format(startDate),
      if (endDate != null)
        'data_zakonczenia': DateFormat('yyyy-MM-dd').format(endDate!),
      'aktywne': isActive,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return {
      'nr_konta_docelowego': targetAccountNumber,
      'nazwa_odbiorcy': recipientName,
      'tytul_przelewu': transferTitle,
      'kwota': amount,
      'czestotliwosc': frequency,
      'data_startu': DateFormat('yyyy-MM-dd').format(startDate),
      if (endDate != null)
        'data_zakonczenia': DateFormat('yyyy-MM-dd').format(endDate!),
      'aktywne': isActive,
    };
  }
}