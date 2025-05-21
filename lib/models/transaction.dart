// lib/models/transaction.dart

class Transaction {
  final int id;
  final String transactionType; // Przechowuje 'typ_transakcji' lub 'typ' z JSON
  final int? senderAccountId;
  final String? senderAccountNumber;
  final String recipientAccountNumber;
  final String recipientName;
  final String? recipientAddressLine1;
  final String? recipientAddressLine2;
  final String title;
  final double amount;
  final String currency;
  final String status;
  final DateTime orderDate;
  final DateTime? executionDate;
  final String? returnInformation;
  final DateTime createdAt;

  Transaction({
    required this.id,
    required this.transactionType,
    this.senderAccountId,
    this.senderAccountNumber,
    required this.recipientAccountNumber,
    required this.recipientName,
    this.recipientAddressLine1,
    this.recipientAddressLine2,
    required this.title,
    required this.amount,
    required this.currency,
    required this.status,
    required this.orderDate,
    this.executionDate,
    this.returnInformation,
    required this.createdAt,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    String transactionCurrency = 'N/A'; // Domyślna wartość
    if (json.containsKey('waluta_przelewu') && json['waluta_przelewu'] != null) {
      transactionCurrency = json['waluta_przelewu'] as String;
    } else if (json.containsKey('waluta') && json['waluta'] != null) {
      transactionCurrency = json['waluta'] as String;
    }

    return Transaction(
      id: json['id'] as int,
      // Preferujemy 'typ_transakcji', jeśli istnieje; inaczej 'typ'
      transactionType: json['typ_transakcji'] as String? ?? (json['typ'] as String? ?? 'Nieznany'),
      senderAccountId: json['id_konta_nadawcy'] as int?,
      senderAccountNumber: json['nr_konta_nadawcy'] as String?,
      recipientAccountNumber: json['nr_konta_odbiorcy'] as String? ?? 'Brak danych',
      recipientName: json['nazwa_odbiorcy'] as String? ?? 'Brak danych',
      recipientAddressLine1: json['adres_odbiorcy_linia1'] as String?,
      recipientAddressLine2: json['adres_odbiorcy_linia2'] as String?,
      title: json['tytul'] as String? ?? 'Brak tytułu',
      amount: (json['kwota'] as num? ?? 0).toDouble(),
      currency: transactionCurrency,
      status: json['status'] as String? ?? 'Nieznany',
      orderDate: DateTime.tryParse(json['data_zlecenia'] as String? ?? '') ?? DateTime(1970),
      executionDate: json['data_realizacji'] != null && (json['data_realizacji'] as String).isNotEmpty
          ? DateTime.tryParse(json['data_realizacji'] as String)
          : null,
      returnInformation: json['informacja_zwrotna'] as String?,
      createdAt: DateTime.tryParse(json['utworzono'] as String? ?? (json['created_at'] as String? ?? '')) ?? DateTime(1970),
    );
  }

  bool get isIncoming {
    // Logika bazuje na polu `transactionType`.
    // Dostosuj, jeśli API dostarcza bardziej jednoznaczny wskaźnik.
    if (transactionType.toLowerCase().contains('przychodzacy')) {
      return true;
    }
    if (transactionType.toLowerCase().contains('wychodzacy')) {
      return false;
    }
    // Fallback na podstawie kwoty, jeśli typ nie jest jednoznaczny
    // (choć to może być mylące dla przelewów na tę samą kwotę w obie strony)
    return amount > 0;
  }
}