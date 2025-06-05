import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/transfer_request_data.dart';
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/account_service.dart';
import 'package:mobile_witelon_bank/services/transaction_service.dart';

class TransferScreen extends StatefulWidget {
  static const routeName = '/transfer';

  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isLoadingAccounts = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  final _recipientAccountController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _recipientAddress1Controller = TextEditingController();
  final _recipientAddress2Controller = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  List<BankAccount> _userAccounts = [];
  BankAccount? _selectedSenderAccount;

  @override
  void initState() {
    super.initState();
    _loadUserAccounts();
  }

  Future<void> _loadUserAccounts() async {
    setState(() { _isLoadingAccounts = true; _feedbackMessage = null; });
    print("DEBUG: TransferScreen - Loading user accounts...");
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.isAuthenticated && authService.token != null) {
        final accountService = AccountService(
          apiBaseUrl: AuthService.apiBaseUrl,
          token: authService.token,
        );
        final accounts = await accountService.getAccounts();
        if (mounted) {
          setState(() {
            _userAccounts = accounts;
            if (_userAccounts.isNotEmpty) {
              _selectedSenderAccount = _userAccounts[0];
              print("DEBUG: TransferScreen - User accounts loaded. Default sender: ${_selectedSenderAccount?.accountNumber}");
            } else {
              print("DEBUG: TransferScreen - User accounts loaded but list is empty.");
              _feedbackMessage = "Brak dostępnych kont do wykonania przelewu.";
              _isSuccess = false;
            }
            _isLoadingAccounts = false;
          });
        }
      } else {
        print("DEBUG: TransferScreen - User not authenticated to load accounts.");
        throw Exception("Użytkownik niezalogowany.");
      }
    } catch (error, stackTrace) {
      print("DEBUG: TransferScreen - Error loading accounts: $error");
      print("DEBUG: TransferScreen - StackTrace for loading accounts error: $stackTrace");
      if (mounted) {
        setState(() {
          _isLoadingAccounts = false;
          _feedbackMessage = "Błąd ładowania kont: ${error.toString().split(':').last.trim()}";
          _isSuccess = false;
        });
      }
    }
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) {
      print("DEBUG: TransferScreen - Form validation FAILED.");
      return;
    }

    if (_selectedSenderAccount == null) {
      print("DEBUG: TransferScreen - _selectedSenderAccount is NULL!");
      setState(() {
        _feedbackMessage = "Proszę wybrać konto nadawcy.";
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    print("DEBUG: TransferScreen - Preparing transfer data:");
    print("DEBUG: Sender Account ID: ${_selectedSenderAccount!.id}");
    print("DEBUG: Recipient Account No: ${_recipientAccountController.text}");
    print("DEBUG: Recipient Name: ${_recipientNameController.text}");
    print("DEBUG: Title: ${_titleController.text}");
    print("DEBUG: Amount (raw from controller): ${_amountController.text}");
    final String cleanedAmountString = _amountController.text.replaceAll(',', '.');
    print("DEBUG: Amount (cleaned string): $cleanedAmountString");
    final double? parsedAmount = double.tryParse(cleanedAmountString);
    print("DEBUG: Parsed Amount: $parsedAmount");
    print("DEBUG: Currency: ${_selectedSenderAccount!.currency}");
    print("DEBUG: Address 1: ${_recipientAddress1Controller.text}");
    print("DEBUG: Address 2: ${_recipientAddress2Controller.text}");

    if (parsedAmount == null) {
      setState(() {
        _isLoading = false;
        _feedbackMessage = "Niepoprawny format kwoty.";
        _isSuccess = false;
      });
      return;
    }

    try {
      final transferData = TransferRequestData(
        senderAccountId: _selectedSenderAccount!.id,
        recipientAccountNumber: _recipientAccountController.text,
        recipientName: _recipientNameController.text,
        recipientAddressLine1: _recipientAddress1Controller.text.isNotEmpty ? _recipientAddress1Controller.text : null,
        recipientAddressLine2: _recipientAddress2Controller.text.isNotEmpty ? _recipientAddress2Controller.text : null,
        title: _titleController.text,
        amount: parsedAmount,
        currency: _selectedSenderAccount!.currency,
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final transactionService = TransactionService(
        apiBaseUrl: AuthService.apiBaseUrl,
        token: authService.token!,
      );

      print("DEBUG: TransferScreen - Calling transactionService.makeTransfer...");
      final Transaction createdTransaction = await transactionService.makeTransfer(transferData);

      if (mounted) {

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Przelew zlecony pomyślnie! ID: ${createdTransaction.id}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (error, stackTrace) {
      print("DEBUG: TransferScreen - Error in _submitTransfer: $error");
      print("DEBUG: TransferScreen - StackTrace for _submitTransfer error: $stackTrace");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _feedbackMessage = "Błąd przelewu: ${error.toString().split(':').last.trim()}";
        });
      }
    }
  }

  @override
  void dispose() {
    _recipientAccountController.dispose();
    _recipientNameController.dispose();
    _recipientAddress1Controller.dispose();
    _recipientAddress2Controller.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nowy Przelew'),
      ),
      body: _isLoadingAccounts
          ? const Center(child: CircularProgressIndicator(key: ValueKey("loadingAccountsIndicator")))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (_feedbackMessage != null && !_isLoading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Text(
                    _feedbackMessage!,
                    style: TextStyle(color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700, fontSize: 14, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_userAccounts.isNotEmpty)
                DropdownButtonFormField<BankAccount>(
                  value: _selectedSenderAccount,
                  decoration: const InputDecoration(
                    labelText: 'Z konta',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance_wallet),
                  ),
                  items: _userAccounts.map((BankAccount account) {
                    return DropdownMenuItem<BankAccount>(
                      value: account,
                      child: Text('${account.accountNumber} (${account.balance.toStringAsFixed(2)} ${account.currency})'),
                    );
                  }).toList(),
                  onChanged: (BankAccount? newValue) {
                    setState(() {
                      _selectedSenderAccount = newValue;
                    });
                  },
                  validator: (value) => value == null ? 'Proszę wybrać konto' : null,
                )
              else if (!_isLoading && _userAccounts.isEmpty && _feedbackMessage == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    _feedbackMessage ?? 'Brak dostępnych kont do wykonania przelewu. Upewnij się, że jesteś zalogowany i masz przypisane konta.',
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _recipientAccountController,
                decoration: const InputDecoration(labelText: 'Numer konta odbiorcy (IBAN)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Pole wymagane';
                  if (!RegExp(r'^PL\d{26}$').hasMatch(value)) return 'Niepoprawny format IBAN PL (PL + 26 cyfr)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientNameController,
                decoration: const InputDecoration(labelText: 'Nazwa odbiorcy', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (value) => value == null || value.isEmpty ? 'Pole wymagane' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Tytuł przelewu', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title)),
                validator: (value) => value == null || value.isEmpty ? 'Pole wymagane' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Kwota',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.attach_money),
                  suffixText: _selectedSenderAccount?.currency ?? 'PLN',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]?\d{0,2})')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Pole wymagane';
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return 'Niepoprawna kwota (musi być większa od 0)';
                  if (_selectedSenderAccount != null && amount > _selectedSenderAccount!.balance) {
                    return 'Niewystarczające środki na wybranym koncie';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientAddress1Controller,
                decoration: const InputDecoration(labelText: 'Adres odbiorcy - linia 1 (opcjonalne)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientAddress2Controller,
                decoration: const InputDecoration(labelText: 'Adres odbiorcy - linia 2 (opcjonalne)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city_outlined)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Wykonaj Przelew'),
                onPressed: (_isLoading || _isLoadingAccounts || _userAccounts.isEmpty) ? null : _submitTransfer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}