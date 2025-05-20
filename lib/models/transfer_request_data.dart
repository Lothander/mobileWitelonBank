class TransferRequestData {
  final int senderAccountId;
  final String recipientAccountNumber;
  final String recipientName;
  final String? recipientAddressLine1;
  final String? recipientAddressLine2;
  final String title;
  final double amount;
  final String currency;

  TransferRequestData({
    required this.senderAccountId,
    required this.recipientAccountNumber,
    required this.recipientName,
    this.recipientAddressLine1,
    this.recipientAddressLine2,
    required this.title,
    required this.amount,
    required this.currency,
  });

  Map<String, dynamic> toJson() {
    return {
      'id_konta_nadawcy': senderAccountId,
      'nr_konta_odbiorcy': recipientAccountNumber,
      'nazwa_odbiorcy': recipientName,
      if (recipientAddressLine1 != null && recipientAddressLine1!.isNotEmpty)
        'adres_odbiorcy_linia1': recipientAddressLine1,
      if (recipientAddressLine2 != null && recipientAddressLine2!.isNotEmpty)
        'adres_odbiorcy_linia2': recipientAddressLine2,
      'tytul': title,
      'kwota': amount,
      'waluta_przelewu': currency,
    };
  }
}