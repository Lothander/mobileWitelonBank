import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/account_service.dart';
import 'package:mobile_witelon_bank/services/transaction_service.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/screens/transaction_history_screen.dart';
import 'package:mobile_witelon_bank/screens/transfer_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_cards_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_standing_orders_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_recipients_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<BankAccount>>? _accountsFuture;
  List<BankAccount> _userAccounts = [];
  BankAccount? _selectedAccount;

  List<Transaction> _recentTransactions = [];
  bool _isLoadingRecentTransactions = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accountsFuture == null) {
      _loadAccountDataAndRecentTransactions();
    }
  }

  Future<void> _loadAccountDataAndRecentTransactions() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isAuthenticated || authService.token == null) {
      if (mounted) {
        setState(() {
          _accountsFuture = Future.error(Exception("Użytkownik niezalogowany."));
          _userAccounts = [];
          _selectedAccount = null;
          _recentTransactions = [];
        });
      }
      return;
    }

    if (_accountsFuture == null && mounted) {
      final accountService = AccountService(
        apiBaseUrl: AuthService.apiBaseUrl,
        token: authService.token,
      );
      setState(() {
        _accountsFuture = accountService.getAccounts();
      });
    }

    try {
      final accounts = await _accountsFuture;
      if (mounted) {
        BankAccount? newSelectedAccount = _selectedAccount;
        if (accounts != null && accounts.isNotEmpty) {
          _userAccounts = accounts;
          if (newSelectedAccount == null ||
              !accounts.any((acc) => acc.id == newSelectedAccount!.id)) {
            newSelectedAccount = accounts[0];
          }
        } else {
          _userAccounts = [];
          newSelectedAccount = null;
        }

        bool shouldLoadTransactions =
            (_selectedAccount?.id != newSelectedAccount?.id) ||
                _recentTransactions.isEmpty;

        setState(() {
          _selectedAccount = newSelectedAccount;
        });

        if (newSelectedAccount != null && shouldLoadTransactions) {
          await _loadRecentTransactionsForAccount(newSelectedAccount);
        } else if (newSelectedAccount == null) {
          if (mounted) setState(() => _recentTransactions = []);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _userAccounts = [];
          _selectedAccount = null;
          _recentTransactions = [];
        });
      }
    }
  }

  Future<void> _loadRecentTransactionsForAccount(BankAccount account) async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecentTransactions = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final transactionService = TransactionService(
        apiBaseUrl: AuthService.apiBaseUrl,
        token: authService.token!,
      );
      final transactions = await transactionService.getTransactionHistory(
        account.id,
        perPage: 3,
        page: 1,
      );
      if (mounted) {
        setState(() {
          _recentTransactions = transactions;
          _isLoadingRecentTransactions = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingRecentTransactions = false;
          _recentTransactions = [];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUser?.name ?? 'Użytkowniku';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Główny'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () =>
                Provider.of<AuthService>(context, listen: false).logout(),
            tooltip: 'Wyloguj',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _accountsFuture = null;
                _userAccounts = [];
                _selectedAccount = null;
                _recentTransactions = [];
              });
              _loadAccountDataAndRecentTransactions();
            },
            tooltip: 'Odśwież dane',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Witaj, $userName!',
                style:
                const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            if (_userAccounts.isNotEmpty) ...[
              DropdownButtonFormField<BankAccount>(
                value: _selectedAccount,
                decoration: InputDecoration(
                  labelText: 'Wybierz konto',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary),
                ),
                items: _userAccounts.map((BankAccount account) {
                  return DropdownMenuItem<BankAccount>(
                    value: account,
                    child: Text('${account.accountNumber} (${account.currency})',
                        overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (BankAccount? newValue) {
                  if (newValue != null && mounted) {
                    setState(() {
                      _selectedAccount = newValue;
                      _recentTransactions = [];
                    });
                    _loadRecentTransactionsForAccount(newValue);
                  }
                },
                isExpanded: true,
              ),
              const SizedBox(height: 20),
            ],
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Saldo wybranego konta:',
                        style:
                        TextStyle(fontSize: 18, color: Colors.grey[700])),
                    const SizedBox(height: 8),
                    FutureBuilder<List<BankAccount>>(
                      future: _accountsFuture,
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting &&
                            _selectedAccount == null &&
                            _userAccounts.isEmpty) {
                          return const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [CircularProgressIndicator()]);
                        } else if (snapshot.hasError &&
                            _selectedAccount == null &&
                            _userAccounts.isEmpty) {
                          return Text(
                              'Błąd: ${snapshot.error.toString().split(':').last.trim()}',
                              style: const TextStyle(
                                  fontSize: 18, color: Colors.red),
                              textAlign: TextAlign.center);
                        } else if (_selectedAccount != null) {
                          return Text(
                            '${_selectedAccount!.balance.toStringAsFixed(2)} ${_selectedAccount!.currency}',
                            style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.green),
                            key: ValueKey('balanceDisplay_${_selectedAccount!.id}'),
                            textAlign: TextAlign.center,
                          );
                        } else if (_userAccounts.isEmpty &&
                            snapshot.connectionState !=
                                ConnectionState.waiting) {
                          return const Text('Brak przypisanych kont.',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.orange),
                              textAlign: TextAlign.center);
                        }
                        return const Text('Wybierz konto, aby zobaczyć saldo.',
                            style:
                            TextStyle(fontSize: 18, color: Colors.grey),
                            textAlign: TextAlign.center);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text('Szybkie Akcje',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Nowy Przelew'),
                  onPressed: (_selectedAccount == null && _userAccounts.isNotEmpty)
                      ? null
                      : () async {
                    if (_userAccounts.isEmpty &&
                        _selectedAccount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                              Text('Brak kont do wykonania przelewu.')));
                      return;
                    }
                    final result = await Navigator.of(context)
                        .pushNamed(TransferScreen.routeName);
                    if (result == true && mounted) {
                      _loadAccountDataAndRecentTransactions();
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Historia Transakcji'),
                  onPressed: (_selectedAccount == null && _userAccounts.isNotEmpty)
                      ? null
                      : () {
                    if (_selectedAccount != null) {
                      Navigator.of(context).pushNamed(
                          TransactionHistoryScreen.routeName,
                          arguments: _selectedAccount!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Wybierz konto, aby zobaczyć historię lub brak kont.')));
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Zarządzaj Kartami'),
                  onPressed: (_selectedAccount == null && _userAccounts.isNotEmpty)
                      ? null
                      : () {
                    if (_selectedAccount != null) {
                      Navigator.of(context).pushNamed(
                          ManageCardsScreen.routeName,
                          arguments: _selectedAccount!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text(
                                  'Wybierz konto, aby zarządzać kartami lub brak kont.')));
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.event_repeat),
                  label: const Text('Zlecenia Stałe'),
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(ManageStandingOrdersScreen.routeName);
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.people_alt_outlined),
                  label: const Text('Zapisani Odbiorcy'),
                  onPressed: () {
                    Navigator.of(context)
                        .pushNamed(ManageRecipientsScreen.routeName);
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text('Ostatnie Transakcje',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: _isLoadingRecentTransactions
                  ? const Center(child: CircularProgressIndicator())
                  : _recentTransactions.isEmpty
                  ? const Center(child: Text('Brak ostatnich transakcji.'))
                  : ListView.builder(
                itemCount: _recentTransactions.length,
                itemBuilder: (context, index) {
                  final transaction = _recentTransactions[index];
                  final bool isIncoming = transaction.isIncoming;
                  return ListTile(
                    leading: Icon(
                      isIncoming
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      color: isIncoming
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                    ),
                    title: Text(transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                        isIncoming
                            ? (transaction.senderAccountNumber != null &&
                            transaction
                                .senderAccountNumber!.isNotEmpty
                            ? 'Od: ${transaction.senderAccountNumber}'
                            : transaction.recipientName.isNotEmpty
                            ? 'Od: ${transaction.recipientName}'
                            : transaction.transactionType)
                            : 'Do: ${transaction.recipientName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    trailing: Text(
                      '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isIncoming
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}