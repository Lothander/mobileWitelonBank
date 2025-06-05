// lib/screens/transaction_history_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/transaction_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  static const routeName = '/transaction-history';
  final BankAccount account;

  const TransactionHistoryScreen({super.key, required this.account});

  @override
  State<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<Transaction>> _transactionsFuture;
  // int _currentPage = 1; // Dla przyszłej paginacji
  // final int _perPage = 15;
  // String? _selectedTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  void _loadTransactionHistory() {
    final authService = Provider.of<AuthService>(context, listen: false);
    print("DEBUG: TransactionHistoryScreen - Loading history for account ID: ${widget.account.id}");
    if (authService.isAuthenticated && authService.token != null) {
      final transactionService = TransactionService(
        apiBaseUrl: AuthService.apiBaseUrl,
        token: authService.token,
      );
      setState(() {
        _transactionsFuture = transactionService.getTransactionHistory(
          widget.account.id,
          // page: _currentPage, // Dla przyszłej paginacji
          // perPage: _perPage,
          // type: _selectedTypeFilter,
        );
      });
    } else {
      setState(() {
        _transactionsFuture = Future.error(Exception("Użytkownik niezalogowany."));
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd.MM.yyyy HH:mm').format(dateTime);
  }

  String _formatCurrency(double amount, String currency) {
    return '${amount.toStringAsFixed(2)} $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Historia dla ${widget.account.accountNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTransactionHistory,
            tooltip: 'Odśwież historię',
          ),
        ],
      ),
      body: FutureBuilder<List<Transaction>>(
        future: _transactionsFuture,
        builder: (ctx, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Błąd ładowania historii: ${snapshot.error.toString().split(':').last.trim()}',
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            final transactions = snapshot.data!;
            return ListView.separated(
              itemCount: transactions.length,
              separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (ctx, index) {
                final transaction = transactions[index];
                final bool isIncoming = transaction.isIncoming;

                return ListTile(
                  leading: Icon(
                    isIncoming ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isIncoming ? Colors.green.shade700 : Colors.red.shade700,
                    size: 30,
                  ),
                  title: Text(
                    transaction.title,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIncoming
                            ? (transaction.senderAccountNumber != null && transaction.senderAccountNumber!.isNotEmpty
                            ? 'Od: ${transaction.senderAccountNumber}'
                        // Jeśli to wpłata, a nie ma senderAccountNumber, może to być np. nazwa wpłacającego lub opis.
                        // API w odpowiedzi na przelew zwracało 'nazwa_odbiorcy', ale tu to może być 'nazwa_nadawcy'.
                        // Jeśli 'nazwa_odbiorcy' w modelu Transaction jest dla odbiorcy przelewu wychodzącego.
                        // Warto sprawdzić, jakie dane przychodzą dla transakcji przychodzących.
                        // Na razie, jeśli nie ma nadawcy, wyświetlmy typ transakcji.
                            : transaction.recipientName.isNotEmpty ? 'Od: ${transaction.recipientName}' : transaction.transactionType)
                            : 'Do: ${transaction.recipientName} (${transaction.recipientAccountNumber})',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Data: ${_formatDateTime(transaction.orderDate)}',
                        style: TextStyle(color: Colors.grey[700], fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Text(
                    // Używamy transaction.amount bezpośrednio, jeśli API zwraca kwoty z odpowiednim znakiem
                    // Jeśli API zwraca zawsze dodatnie kwoty, a typ określa kierunek, to:
                    // '${isIncoming ? "+" : "-"} ${transaction.amount.abs().toStringAsFixed(2)} ${transaction.currency}',
                    // Na podstawie logu dla przelewu, kwota była dodatnia, a typ określał kierunek.
                    // Jeśli API dla historii zwraca kwoty z właściwym znakiem (+/-), to poniższe jest OK.
                    // Jeśli nie, trzeba będzie dostosować.
                    '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isIncoming ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                  ),
                  isThreeLine: true,
                  onTap: () {
                    // _showTransactionDetailsDialog(context, transaction);
                  },
                );
              },
            );
          } else if (snapshot.hasData && snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'Brak transakcji do wyświetlenia dla tego konta.',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            );
          }
          return const Center(
            child: Text(
              'Nie udało się załadować historii transakcji.',
              style: TextStyle(fontSize: 16),
            ),
          );
        },
      ),
    );
  }
}