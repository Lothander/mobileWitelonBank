class BankAccount {
  final int id;
  final String accountNumber;
  final double balance;
  final String currency;

  BankAccount({
    required this.id,
    required this.accountNumber,
    required this.balance,
    required this.currency,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    final String balanceString = json['saldo'] as String? ?? "0.0";
    final double parsedBalance = double.tryParse(balanceString) ?? 0.0;

    final String currencyValue = json['waluta'] as String? ?? 'N/A'; // Lub 'PLN', lub pusty string ''

    return BankAccount(
      id: json['id'] as int,
      accountNumber: json['nr_konta'] as String? ?? 'Brak numeru',
      balance: parsedBalance,
      currency: currencyValue,
    );
  }
}