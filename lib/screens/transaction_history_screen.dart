import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_saver/file_saver.dart';

import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/transaction_service.dart';

class TransactionHistoryScreen extends StatefulWidget {
  static const routeName = '/transaction-history';
  final BankAccount account;

  const TransactionHistoryScreen({super.key, required this.account});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen> {
  late Future<List<Transaction>> _transactionsFuture;
  List<Transaction> _transactions = [];
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadTransactionHistory();
  }

  TransactionService _getTransactionService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return TransactionService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _loadTransactionHistory() async {
    if (!mounted) return;
    setState(() {
      _isExporting = false;
      _transactionsFuture = _getTransactionService()
          .getTransactionHistory(widget.account.id)
          .then((loadedTransactions) {
        if (mounted) {
          setState(() {
            _transactions = loadedTransactions;
          });
        }
        return loadedTransactions;
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Błąd ładowania historii: ${error.toString().split(':').last.trim()}'),
                backgroundColor: Colors.red),
          );
          setState(() {
            _transactions = [];
          });
        }
        throw error;
      });
    });
  }

  Future<void> _showExportOptionsDialog() async {
    DateTimeRange? selectedDateRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );

    final DateTimeRange? dateRangeResult = await showDialog<DateTimeRange>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('Eksportuj historię do PDF'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text('Wybierz zakres dat:'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final DateTimeRange? picked =
                                await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                                  initialDateRange: selectedDateRange,
                                );
                                if (picked != null)
                                  setDialogState(() => selectedDateRange = picked);
                              },
                              child: Text(DateFormat('dd.MM.yyyy')
                                  .format(selectedDateRange!.start)),
                            )),
                        const Text(" - "),
                        Expanded(
                            child: TextButton(
                              onPressed: () async {
                                final DateTimeRange? picked =
                                await showDateRangePicker(
                                  context: context,
                                  firstDate: DateTime(2000),
                                  lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                                  initialDateRange: selectedDateRange,
                                );
                                if (picked != null)
                                  setDialogState(() => selectedDateRange = picked);
                              },
                              child: Text(DateFormat('dd.MM.yyyy')
                                  .format(selectedDateRange!.end)),
                            )),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text('Anuluj'),
                    onPressed: () => Navigator.of(dialogContext).pop()),
                TextButton(
                  child: const Text('Eksportuj PDF'),
                  onPressed: () =>
                      Navigator.of(dialogContext).pop(selectedDateRange),
                ),
              ],
            );
          },
        );
      },
    );

    if (dateRangeResult != null) {
      _performExport(dateRangeResult.start, dateRangeResult.end, null);
    }
  }

  Future<void> _performExport(
      DateTime dateFrom, DateTime dateTo, String? type) async {
    if (!mounted) return;
    setState(() {
      _isExporting = true;
    });

    final String dateFromString = DateFormat('yyyy-MM-dd').format(dateFrom);
    final String dateToString = DateFormat('yyyy-MM-dd').format(dateTo);

    try {
      await Permission.storage.request();

      final transactionService = _getTransactionService();
      final Uint8List pdfData =
      await transactionService.exportTransactionHistoryToPdf(
        accountId: widget.account.id,
        dateFrom: dateFromString,
        dateTo: dateToString,
        type: type,
      );

      if (pdfData.isEmpty) {
        throw Exception("Otrzymano puste dane PDF z serwera.");
      }

      final String defaultFileName =
          'historia_transakcji_${widget.account.id}_${dateFromString}_do_$dateToString';

      String? filePath = await FileSaver.instance.saveFile(
          name: defaultFileName,
          bytes: pdfData,
          ext: 'pdf',
          mimeType: MimeType.pdf);

      if (mounted) {
        if (filePath != null && filePath.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Historia PDF zapisana! Ścieżka: $filePath'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 7),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                Text('Zapis pliku został anulowany lub nie powiódł się.'),
                backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Błąd eksportu PDF: ${e.toString().split(':').last.trim()}'),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
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
            icon: const Icon(Icons.download_for_offline_outlined),
            onPressed: (_isExporting) ? null : _showExportOptionsDialog,
            tooltip: 'Eksportuj historię (PDF)',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isExporting) ? null : _loadTransactionHistory,
            tooltip: 'Odśwież historię',
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<Transaction>>(
            future: _transactionsFuture,
            builder: (ctx, snapshot) {
              Widget content;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _transactions.isEmpty) {
                content = const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError && _transactions.isEmpty) {
                content = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                        'Błąd ładowania historii: ${snapshot.error.toString().split(':').last.trim()}',
                        style: const TextStyle(
                            color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center),
                  ),
                );
              } else if (_transactions.isNotEmpty) {
                content = ListView.separated(
                  itemCount: _transactions.length,
                  separatorBuilder: (context, index) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (ctx, index) {
                    final transaction = _transactions[index];
                    final bool isIncoming = transaction.isIncoming;

                    return ListTile(
                      leading: Icon(
                        isIncoming
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        color: isIncoming
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        size: 30,
                      ),
                      title: Text(transaction.title,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isIncoming
                                ? (transaction.senderAccountNumber != null &&
                                transaction
                                    .senderAccountNumber!.isNotEmpty
                                ? 'Od: ${transaction.senderAccountNumber}'
                                : transaction.recipientName.isNotEmpty
                                ? 'Od: ${transaction.recipientName}'
                                : transaction.transactionType)
                                : 'Do: ${transaction.recipientName} (${transaction.recipientAccountNumber})',
                            style:
                            TextStyle(color: Colors.grey[700], fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                              'Data: ${_formatDateTime(transaction.orderDate)}',
                              style: TextStyle(
                                  color: Colors.grey[700], fontSize: 12)),
                        ],
                      ),
                      trailing: Text(
                        _formatCurrency(transaction.amount, transaction.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isIncoming
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                        ),
                      ),
                      isThreeLine: true,
                    );
                  },
                );
              } else {
                content = const Center(
                  child: Text(
                      'Brak transakcji do wyświetlenia dla tego konta.',
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center),
                );
              }
              return content;
            },
          ),
          if (_isExporting)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("Eksportowanie PDF...",
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}