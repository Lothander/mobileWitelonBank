import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/account_service.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/screens/transaction_history_screen.dart';
import 'package:mobile_witelon_bank/screens/transfer_screen.dart';

class DashboardScreen extends StatefulWidget {
  static const routeName = '/dashboard';

  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Future<List<BankAccount>>? _accountsFuture;
  BankAccount? _selectedAccount;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_accountsFuture == null) {
      _loadAccountData();
    }
  }

  void _loadAccountData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.isAuthenticated && authService.token != null) {
      final accountService = AccountService(
        apiBaseUrl: _DashboardScreenState.AuthService_apiBaseUrl,
        token: authService.token,
      );
      setState(() {
        _accountsFuture = accountService.getAccounts().then((accounts) {
          if (accounts.isNotEmpty) {
            _selectedAccount = accounts[0];
          }
          return accounts;
        }).catchError((error) {
          _selectedAccount = null;
          throw error;
        });
      });
    } else {
      print("DashboardScreen: User not authenticated or token missing, cannot load balance.");
      setState(() {
        _accountsFuture = Future.error(Exception("Użytkownik niezalogowany."));
        _selectedAccount = null;
      });
    }
  }

  static const String AuthService_apiBaseUrl = 'https://witelonapi.host358482.xce.pl/api';

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
            onPressed: () {
              Provider.of<AuthService>(context, listen: false).logout();
            },
            tooltip: 'Wyloguj',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAccountData,
            tooltip: 'Odśwież dane',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Witaj, $userName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Twoje saldo:',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<List<BankAccount>>(
                      future: _accountsFuture,
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [CircularProgressIndicator()],
                          );
                        } else if (snapshot.hasError) {
                          print("Błąd FutureBuilder salda: ${snapshot.error}");
                          return Text(
                            'Błąd: ${snapshot.error.toString().split(':').sublist(1).join(':').trim()}',
                            style: const TextStyle(fontSize: 18, color: Colors.red),
                            textAlign: TextAlign.center,
                          );
                        } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                          final accountToDisplay = _selectedAccount ?? snapshot.data![0];
                          return Text(
                            '${accountToDisplay.balance.toStringAsFixed(2)} ${accountToDisplay.currency}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                            key: const ValueKey('balanceDisplay'),
                            textAlign: TextAlign.center,
                          );
                        } else if (snapshot.hasData && snapshot.data!.isEmpty) {
                          return const Text(
                            'Brak przypisanych kont.',
                            style: TextStyle(fontSize: 18, color: Colors.orange),
                            textAlign: TextAlign.center,
                          );
                        }
                        return const Text(
                          'Nie udało się załadować salda.',
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                          textAlign: TextAlign.center,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'Szybkie Akcje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10.0,
              runSpacing: 10.0,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.send),
                  label: const Text('Nowy Przelew'),
                  onPressed: () {
                    Navigator.of(context).pushNamed(TransferScreen.routeName); // Zaktualizowana nawigacja
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Historia Transakcji'),
                  onPressed: () {
                    if (_selectedAccount != null) {
                      Navigator.of(context).pushNamed(
                        TransactionHistoryScreen.routeName,
                        arguments: _selectedAccount!,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Dane konta nie są jeszcze dostępne lub brak kont.')),
                      );
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.credit_card),
                  label: const Text('Zarządzaj Kartami'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Funkcja "Zarządzaj Kartami" wkrótce! (WBK-12)')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Ostatnie Transakcje',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: ListView(
                children: const [
                  ListTile(leading: Icon(Icons.arrow_downward, color: Colors.green), title: Text('Wynagrodzenie'), trailing: Text('+ 5,000.00 PLN')),
                  ListTile(leading: Icon(Icons.arrow_upward, color: Colors.red), title: Text('Zakupy spożywcze'), trailing: Text('- 150.25 PLN')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}