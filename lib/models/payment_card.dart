// lib/models/payment_card.dart

class PaymentCard {
  final int id;
  final int accountId;
  final String cardNumber; // Będzie przechowywać zamaskowany numer
  final DateTime expiryDate;
  final bool isBlocked;
  final double dailyLimit;
  final String cardType;
  final bool? internetPaymentsActive; // Nowe pole
  final bool? contactlessPaymentsActive; // Nowe pole
  //created_at i updated_at są w odpowiedzi, ale pomijamy je w modelu na razie dla uproszczenia

  PaymentCard({
    required this.id,
    required this.accountId,
    required this.cardNumber, // To będzie nr_karty_masked lub nr_karty
    required this.expiryDate,
    required this.isBlocked,
    required this.dailyLimit,
    required this.cardType,
    this.internetPaymentsActive,
    this.contactlessPaymentsActive,
  });

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    // Sprawdzamy, który klucz dla numeru karty jest dostępny
    String cardNumberValue = 'Brak numeru';
    if (json.containsKey('nr_karty_masked') && json['nr_karty_masked'] != null) {
      cardNumberValue = json['nr_karty_masked'] as String;
    } else if (json.containsKey('nr_karty') && json['nr_karty'] != null) {
      cardNumberValue = json['nr_karty'] as String;
    }

    // Obsługa 'limit_dzienny' jako String lub Number
    double parsedDailyLimit = 0.0;
    if (json['limit_dzienny'] != null) {
      if (json['limit_dzienny'] is String) {
        parsedDailyLimit = double.tryParse((json['limit_dzienny'] as String).replaceAll(',', '.')) ?? 0.0;
      } else if (json['limit_dzienny'] is num) {
        parsedDailyLimit = (json['limit_dzienny'] as num).toDouble();
      }
    }

    // id_konta może być bezpośrednio lub w zagnieżdżonym obiekcie 'konto'
    int accId;
    if (json.containsKey('id_konta')) {
      accId = json['id_konta'] as int? ?? 0;
    } else if (json.containsKey('konto') && json['konto'] is Map) {
      accId = (json['konto'] as Map<String, dynamic>)['id'] as int? ?? 0;
    } else {
      accId = 0; // Domyślna wartość, jeśli nie znaleziono
    }


    return PaymentCard(
      id: json['id'] as int? ?? 0, // Jeśli ID może brakować w jakiejś odpowiedzi
      accountId: accId,
      cardNumber: cardNumberValue,
      expiryDate: DateTime.tryParse(json['data_waznosci'] as String? ?? '') ?? DateTime(1970),
      isBlocked: json['zablokowana'] as bool? ?? true,
      dailyLimit: parsedDailyLimit,
      cardType: json['typ_karty'] as String? ?? 'Nieznany',
      internetPaymentsActive: json['platnosci_internetowe_aktywne'] as bool?,
      contactlessPaymentsActive: json['platnosci_zblizeniowe_aktywne'] as bool?,
    );
  }

  PaymentCard copyWith({
    bool? isBlocked,
    double? dailyLimit,
    bool? internetPaymentsActive,
    bool? contactlessPaymentsActive,
    // Dodajemy, bo API je zwraca po PATCH
  }) {
    return PaymentCard(
      id: id,
      accountId: accountId,
      cardNumber: cardNumber,
      expiryDate: expiryDate,
      isBlocked: isBlocked ?? this.isBlocked,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      cardType: cardType,
      internetPaymentsActive: internetPaymentsActive ?? this.internetPaymentsActive,
      contactlessPaymentsActive: contactlessPaymentsActive ?? this.contactlessPaymentsActive,
    );
  }

  // Getter maskedCardNumber nie jest już tak potrzebny, jeśli API zwraca nr_karty_masked
  // ale zostawmy go, jeśli nr_karty czasami jest pełny.
  // W UI będziemy używać po prostu pola `cardNumber`.
  String get maskedCardNumber {
    // Jeśli pole cardNumber już jest zamaskowane przez API (np. zawiera "****")
    if (cardNumber.contains('*')) {
      return cardNumber;
    }
    // Jeśli to pełny numer, maskujemy go
    if (cardNumber.length > 4) {
      return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
    }
    return cardNumber;
  }
}