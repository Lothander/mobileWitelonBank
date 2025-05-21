// lib/screens/dashboard_screen.dart
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
  List<BankAccount> _userAccounts = []; // Lista do przechowywania pobranych kont
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
      // Nie używamy setState bezpośrednio na _accountsFuture tutaj,
      // aby uniknąć wielokrotnego przebudowywania całego drzewa przez FutureBuilder,
      // jeśli tylko zmieniamy _selectedAccount.
      // FutureBuilder będzie nadal używał początkowego _accountsFuture.
      // Aktualizujemy _userAccounts i _selectedAccount, co spowoduje przebudowę Dropdown i salda.

      // Przypisujemy future, aby FutureBuilder mógł na nim operować
      // Robimy to tylko raz, aby uniknąć ponownego ładowania przy każdym setState
      if (mounted && _accountsFuture == null) { // Zabezpieczenie przed wielokrotnym przypisaniem
        _accountsFuture = accountService.getAccounts();
      }

      // Po pobraniu danych, aktualizujemy stan komponentu
      _accountsFuture?.then((accounts) {
        if (mounted) {
          setState(() {
            _userAccounts = accounts;
            if (accounts.isNotEmpty && _selectedAccount == null) { // Ustaw domyślne tylko jeśli jeszcze nie wybrano
              _selectedAccount = accounts[0];
            } else if (accounts.isNotEmpty && _selectedAccount != null) {
              // Upewnij się, że _selectedAccount jest nadal ważnym kontem z listy
              // (np. po odświeżeniu, jeśli lista kont się zmieniła)
              // Ta logika może być bardziej skomplikowana, jeśli ID kont mogą się zmieniać.
              // Na razie zakładamy, że odświeżenie nie zmienia ID istniejących kont.
              bool currentSelectionIsValid = accounts.any((acc) => acc.id == _selectedAccount!.id);
              if (!currentSelectionIsValid) {
                _selectedAccount = accounts[0];
              }
            } else { // Jeśli lista kont jest pusta
              _selectedAccount = null;
            }
          });
        }
        return accounts; // Zwracamy dla FutureBuilder, jeśli jest to pierwsze ładowanie
      }).catchError((error) {
        if (mounted) {
          setState(() {
            _userAccounts = []; // Wyczyść listę kont w przypadku błędu
            _selectedAccount = null;
          });
        }
        // Błąd zostanie obsłużony przez FutureBuilder
        // throw error; // Nie rzucamy tutaj, aby FutureBuilder obsłużył stan błędu
      });

      // Aby FutureBuilder się przebudował, jeśli future już istnieje, ale chcemy odświeżyć
      if (mounted && _accountsFuture != null) {
        setState(() {});
      }

    } else {
      print("DashboardScreen: User not authenticated or token missing, cannot load data.");
      if (mounted) {
        setState(() {
          _accountsFuture = Future.error(Exception("Użytkownik niezalogowany."));
          _userAccounts = [];
          _selectedAccount = null;
        });
      }
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
            onPressed: (){
              // Resetujemy future, aby wymusić ponowne załadowanie i przebudowanie FutureBuilder
              setState(() {
                _accountsFuture = null;
                _userAccounts = [];
                _selectedAccount = null;
              });
              _loadAccountData();
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
            Text(
              'Witaj, $userName!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // Dropdown do wyboru konta
            if (_userAccounts.isNotEmpty) ...[
              DropdownButtonFormField<BankAccount>(
                value: _selectedAccount,
                decoration: InputDecoration(
                  labelText: 'Wybierz konto',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: Icon(Icons.account_balance_wallet, color: Theme.of(context).colorScheme.primary),
                ),
                items: _userAccounts.map((BankAccount account) {
                  return DropdownMenuItem<BankAccount>(
                    value: account,
                    child: Text(
                      '${account.accountNumber} (${account.currency})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (BankAccount? newValue) {
                  setState(() {
                    _selectedAccount = newValue;
                    // Nie ma potrzeby ponownego wywoływania _loadAccountData(),
                    // FutureBuilder dla salda powinien się przebudować,
                    // jeśli _selectedAccount jest używany w jego builderze,
                    // lub jeśli zmieniamy klucz FutureBuilder.
                    // W tym przypadku, po prostu przebudowujemy UI.
                  });
                },
                isExpanded: true,
              ),
              const SizedBox(height: 20),
            ],

            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text( // Usunięto numer konta z tej etykiety
                      'Saldo wybranego konta:',
                      style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 8),
                    // FutureBuilder teraz głównie do obsługi stanu ładowania/błędu początkowego.
                    // Wyświetlanie salda opiera się na _selectedAccount.
                    FutureBuilder<List<BankAccount>>(
                      future: _accountsFuture, // Używamy tego samego future
                      builder: (ctx, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && _selectedAccount == null) {
                          return const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [CircularProgressIndicator()],
                          );
                        } else if (snapshot.hasError && _selectedAccount == null) {
                          print("Błąd FutureBuilder salda: ${snapshot.error}");
                          return Text(
                            'Błąd: ${snapshot.error.toString().split(':').last.trim()}',
                            style: const TextStyle(fontSize: 18, color: Colors.red),
                            textAlign: TextAlign.center,
                          );
                        } else if (_selectedAccount != null) { // Jeśli mamy wybrane konto, wyświetlamy jego saldo
                          return Text(
                            '${_selectedAccount!.balance.toStringAsFixed(2)} ${_selectedAccount!.currency}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green),
                            key: ValueKey('balanceDisplay_${_selectedAccount!.id}'), // Klucz zmienia się z kontem
                            textAlign: TextAlign.center,
                          );
                        } else if (_userAccounts.isEmpty && snapshot.connectionState != ConnectionState.waiting) {
                          return const Text(
                            'Brak przypisanych kont.',
                            style: TextStyle(fontSize: 18, color: Colors.orange),
                            textAlign: TextAlign.center,
                          );
                        }
                        // Stan, gdy nie ma wybranego konta, ale lista nie jest pusta
                        // lub jakiś inny nieoczekiwany stan
                        return const Text(
                          'Wybierz konto, aby zobaczyć saldo.',
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
                  onPressed: (_selectedAccount == null && _userAccounts.isNotEmpty) ? null : () async { // Wyłącz, jeśli nie ma wybranego konta a są jakieś do wyboru
                    if (_userAccounts.isEmpty && _selectedAccount == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Brak kont do wykonania przelewu.')),
                      );
                      return;
                    }
                    final result = await Navigator.of(context).pushNamed(
                      TransferScreen.routeName,
                      // Można przekazać _selectedAccount do TransferScreen,
                      // aby domyślnie było wybrane jako konto nadawcy,
                      // ale TransferScreen i tak ładuje listę kont.
                    );
                    if (result == true && mounted) {
                      print("DEBUG: DashboardScreen - Transfer successful, refreshing account data...");
                      _loadAccountData();
                    }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.history),
                  label: const Text('Historia Transakcji'),
                  onPressed: (_selectedAccount == null && _userAccounts.isNotEmpty) ? null : () { // Wyłącz, jeśli nie ma wybranego konta
                    if (_selectedAccount != null) {
                      Navigator.of(context).pushNamed(
                        TransactionHistoryScreen.routeName,
                        arguments: _selectedAccount!,
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Wybierz konto, aby zobaczyć historię lub brak kont.')),
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
              'Ostatnie Transakcje', // TODO: Też powinny być dla wybranego konta
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