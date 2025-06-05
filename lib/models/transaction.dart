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
    String transactionCurrency = 'N/A';
    if (json.containsKey('waluta_przelewu') && json['waluta_przelewu'] != null) {
      transactionCurrency = json['waluta_przelewu'] as String;
    } else if (json.containsKey('waluta') && json['waluta'] != null) {
      transactionCurrency = json['waluta'] as String;
    }

    return Transaction(
      id: json['id'] as int? ?? 0, // Dodano ?? 0 dla bezpieczeństwa
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

  // Poprawiony getter isIncoming, aby bazował na polu transactionType
  // Załóżmy, że API dla 'typ_transakcji' lub 'typ' zwraca coś zawierającego 'przychodzacy' dla wpłat
  bool get isIncoming {
    // Przykładowe wartości, które mogą oznaczać transakcję przychodzącą. Dostosuj do swojego API.
    List<String> incomingKeywords = ['przychodzacy', 'incoming', 'credit', 'wpłata'];
    for (String keyword in incomingKeywords) {
      if (transactionType.toLowerCase().contains(keyword)) {
        return true;
      }
    }
    // Jeśli typ nie jest jednoznacznie przychodzący, a kwota jest dodatnia, można to uznać za przychodzącą.
    // Jednak jeśli API zawsze ustawia typ_transakcji, ta druga część może nie być potrzebna.
    // Sprawdź, jak Twoje API oznacza przelewy wewnętrzne (między własnymi kontami), jeśli kwota może być dodatnia.
    // Wcześniej miałeś też w logu pole "typ": "przychodzacy" - jeśli ono jest bardziej wiarygodne,
    // to `transactionType` powinno przechowywać wartość z `json['typ']` z priorytetem.
    // W obecnej implementacji Transaction.fromJson:
    // transactionType: json['typ_transakcji'] as String? ?? (json['typ'] as String? ?? 'Nieznany'),
    // to pole transactionType będzie zawierało wartość z 'typ_transakcji' lub 'typ'.
    return amount > 0 && !transactionType.toLowerCase().contains('wychodzacy'); // Ostrożniejsze założenie
  }
}