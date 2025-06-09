class SavedRecipient {
  final int id;
  final int? userId;
  final String definedName;
  final String accountNumber;
  final String actualRecipientName;
  final String? addressLine1;
  final String? addressLine2;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  SavedRecipient({
    required this.id,
    this.userId,
    required this.definedName,
    required this.accountNumber,
    required this.actualRecipientName,
    this.addressLine1,
    this.addressLine2,
    this.createdAt,
    this.updatedAt,
  });

  factory SavedRecipient.fromJson(Map<String, dynamic> json) {
    DateTime? tryParseApiDate(String? dateString) {
      if (dateString == null || dateString.isEmpty) return null;
      try {
        return DateTime.parse(dateString.replaceFirst(' ', 'T'));
      } catch (e) {
        return null;
      }
    }

    return SavedRecipient(
      id: json['id'] as int? ?? 0,
      userId: json['id_uzytkownika'] as int?,
      definedName: json['nazwa_zdefiniowana'] as String? ??
          json['nazwa_odbiorcy_zdefiniowana'] as String? ??
          'Brak nazwy',
      accountNumber: json['nr_konta'] as String? ??
          json['nr_konta_odbiorcy'] as String? ??
          'Brak numeru',
      actualRecipientName: json['rzeczywista_nazwa'] as String? ??
          json['rzeczywista_nazwa_odbiorcy'] as String? ??
          'Brak danych',
      addressLine1: json['adres_linia1'] as String? ??
          json['adres_odbiorcy_linia1'] as String?,
      addressLine2: json['adres_linia2'] as String? ??
          json['adres_odbiorcy_linia2'] as String?,
      createdAt: tryParseApiDate(
          json['dodano'] as String? ?? json['created_at'] as String?),
      updatedAt: tryParseApiDate(json['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'nazwa_odbiorcy_zdefiniowana': definedName,
      'nr_konta_odbiorcy': accountNumber,
      'rzeczywista_nazwa_odbiorcy': actualRecipientName,
    };
    if (addressLine1 != null && addressLine1!.isNotEmpty) {
      data['adres_odbiorcy_linia1'] = addressLine1;
    }
    if (addressLine2 != null && addressLine2!.isNotEmpty) {
      data['adres_odbiorcy_linia2'] = addressLine2;
    }
    return data;
  }
}