class PaymentCard {
  final int id;
  final int accountId;
  final String cardNumber;
  final DateTime expiryDate;
  final bool isBlocked;
  final double dailyLimit;
  final String cardType;
  final bool? internetPaymentsActive;
  final bool? contactlessPaymentsActive;

  PaymentCard({
    required this.id,
    required this.accountId,
    required this.cardNumber,
    required this.expiryDate,
    required this.isBlocked,
    required this.dailyLimit,
    required this.cardType,
    this.internetPaymentsActive,
    this.contactlessPaymentsActive,
  });

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    String cardNumberValue = 'Brak numeru';
    if (json.containsKey('nr_karty_masked') && json['nr_karty_masked'] != null) {
      cardNumberValue = json['nr_karty_masked'] as String;
    } else if (json.containsKey('nr_karty') && json['nr_karty'] != null) {
      cardNumberValue = json['nr_karty'] as String;
    }

    double parsedDailyLimit = 0.0;
    if (json['limit_dzienny'] != null) {
      if (json['limit_dzienny'] is String) {
        parsedDailyLimit = double.tryParse(
            (json['limit_dzienny'] as String).replaceAll(',', '.')) ??
            0.0;
      } else if (json['limit_dzienny'] is num) {
        parsedDailyLimit = (json['limit_dzienny'] as num).toDouble();
      }
    }

    int accId;
    if (json.containsKey('id_konta')) {
      accId = json['id_konta'] as int? ?? 0;
    } else if (json.containsKey('konto') && json['konto'] is Map) {
      accId = (json['konto'] as Map<String, dynamic>)['id'] as int? ?? 0;
    } else {
      accId = 0;
    }

    return PaymentCard(
      id: json['id'] as int? ?? 0,
      accountId: accId,
      cardNumber: cardNumberValue,
      expiryDate:
      DateTime.tryParse(json['data_waznosci'] as String? ?? '') ??
          DateTime(1970),
      isBlocked: json['zablokowana'] as bool? ?? true,
      dailyLimit: parsedDailyLimit,
      cardType: json['typ_karty'] as String? ?? 'Nieznany',
      internetPaymentsActive: json['platnosci_internetowe_aktywne'] as bool?,
      contactlessPaymentsActive:
      json['platnosci_zblizeniowe_aktywne'] as bool?,
    );
  }

  PaymentCard copyWith({
    bool? isBlocked,
    double? dailyLimit,
    bool? internetPaymentsActive,
    bool? contactlessPaymentsActive,
  }) {
    return PaymentCard(
      id: id,
      accountId: accountId,
      cardNumber: cardNumber,
      expiryDate: expiryDate,
      isBlocked: isBlocked ?? this.isBlocked,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      cardType: cardType,
      internetPaymentsActive:
      internetPaymentsActive ?? this.internetPaymentsActive,
      contactlessPaymentsActive:
      contactlessPaymentsActive ?? this.contactlessPaymentsActive,
    );
  }

  String get maskedCardNumber {
    if (cardNumber.contains('*')) {
      return cardNumber;
    }
    if (cardNumber.length > 4) {
      return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
    }
    return cardNumber;
  }
}