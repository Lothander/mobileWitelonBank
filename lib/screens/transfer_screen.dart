import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/transfer_request_data.dart';
import 'package:mobile_witelon_bank/models/transaction.dart';
import 'package:mobile_witelon_bank/models/saved_recipient.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/account_service.dart';
import 'package:mobile_witelon_bank/services/transaction_service.dart';
import 'package:mobile_witelon_bank/services/recipient_service.dart';

class TransferScreen extends StatefulWidget {
  static const routeName = '/transfer';

  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
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

  List<SavedRecipient> _savedRecipients = [];
  SavedRecipient? _selectedSavedRecipient;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      if (!authService.isAuthenticated || authService.token == null) {
        throw Exception("Użytkownik niezalogowany.");
      }

      final accountService = AccountService(
          apiBaseUrl: AuthService.apiBaseUrl, token: authService.token);
      final recipientService = RecipientService(
          apiBaseUrl: AuthService.apiBaseUrl, token: authService.token);

      final results = await Future.wait([
        accountService.getAccounts(),
        recipientService.getSavedRecipients(),
      ]);

      final accounts = results[0] as List<BankAccount>;
      final recipients = results[1] as List<SavedRecipient>;

      if (mounted) {
        setState(() {
          _userAccounts = accounts;
          if (_userAccounts.isNotEmpty) {
            _selectedSenderAccount = _userAccounts[0];
          } else {
            _selectedSenderAccount = null;
          }

          _savedRecipients = recipients;
          _selectedSavedRecipient = null;
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _feedbackMessage =
          "Błąd ładowania danych: ${error.toString().split(':').last.trim()}";
          _userAccounts = [];
          _selectedSenderAccount = null;
          _savedRecipients = [];
          _selectedSavedRecipient = null;
        });
      }
    }
  }

  void _onSavedRecipientSelected(SavedRecipient? recipient) {
    setState(() {
      _selectedSavedRecipient = recipient;
      if (recipient != null) {
        _recipientAccountController.text = recipient.accountNumber;
        _recipientNameController.text = recipient.actualRecipientName;
        _recipientAddress1Controller.text = recipient.addressLine1 ?? '';
        _recipientAddress2Controller.text = recipient.addressLine2 ?? '';
      }
    });
  }

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedSenderAccount == null) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Proszę wybrać konto nadawcy.'),
            backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    final String cleanedAmountString = _amountController.text.replaceAll(',', '.');
    final double? parsedAmount = double.tryParse(cleanedAmountString);

    if (parsedAmount == null) {
      if (mounted)
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
        recipientAddressLine1: _recipientAddress1Controller.text.isNotEmpty
            ? _recipientAddress1Controller.text
            : null,
        recipientAddressLine2: _recipientAddress2Controller.text.isNotEmpty
            ? _recipientAddress2Controller.text
            : null,
        title: _titleController.text,
        amount: parsedAmount,
        currency: _selectedSenderAccount!.currency,
      );

      final authService = Provider.of<AuthService>(context, listen: false);
      final transactionService = TransactionService(
        apiBaseUrl: AuthService.apiBaseUrl,
        token: authService.token!,
      );

      final Transaction createdTransaction =
      await transactionService.makeTransfer(transferData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text('Przelew zlecony pomyślnie! ID: ${createdTransaction.id}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        _formKey.currentState?.reset();
        _recipientAccountController.clear();
        _recipientNameController.clear();
        _recipientAddress1Controller.clear();
        _recipientAddress2Controller.clear();
        _titleController.clear();
        _amountController.clear();
        setState(() {
          _selectedSavedRecipient = null;
          _isLoading = false;
          _isSuccess = true;
        });

        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _feedbackMessage =
          "Błąd przelewu: ${error.toString().split(':').last.trim()}";
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
      body: _isLoading &&
          (_userAccounts.isEmpty &&
              _savedRecipients.isEmpty &&
              ModalRoute.of(context)?.isCurrent == true)
          ? const Center(
          child:
          CircularProgressIndicator(key: ValueKey("loadingInitialDataIndicator")))
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
                    style: TextStyle(
                        color: _isSuccess
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),
              if (_userAccounts.isNotEmpty)
                DropdownButtonFormField<BankAccount>(
                  value: _selectedSenderAccount,
                  decoration: const InputDecoration(
                      labelText: 'Z konta',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.account_balance_wallet)),
                  isExpanded: true,
                  items: _userAccounts.map((BankAccount account) {
                    return DropdownMenuItem<BankAccount>(
                      value: account,
                      child: Text(
                        '${account.accountNumber} (${account.balance.toStringAsFixed(2)} ${account.currency})',
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    );
                  }).toList(),
                  onChanged: (BankAccount? newValue) =>
                      setState(() => _selectedSenderAccount = newValue),
                  validator: (value) =>
                  value == null ? 'Proszę wybrać konto' : null,
                )
              else if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _feedbackMessage ??
                        'Brak dostępnych kont do wykonania przelewu.',
                    style: TextStyle(
                        color: _feedbackMessage == null
                            ? Colors.grey
                            : Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 16),
              if (_savedRecipients.isNotEmpty) ...[
                DropdownButtonFormField<SavedRecipient>(
                  value: _selectedSavedRecipient,
                  hint: const Text(
                      'Wybierz zapisanego odbiorcę (opcjonalnie)'),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Zapisany odbiorca',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.people_alt_outlined),
                  ),
                  items: _savedRecipients
                      .map((SavedRecipient recipient) {
                    return DropdownMenuItem<SavedRecipient>(
                      value: recipient,
                      child: Text(
                        recipient.definedName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: _onSavedRecipientSelected,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _recipientAccountController,
                decoration: const InputDecoration(
                    labelText: 'Numer konta odbiorcy (IBAN)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance)),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Pole wymagane';
                  if (!RegExp(r'^PL\d{26}$').hasMatch(value))
                    return 'Niepoprawny format IBAN PL (PL + 26 cyfr)';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientNameController,
                decoration: const InputDecoration(
                    labelText: 'Nazwa odbiorcy',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person)),
                validator: (value) =>
                value == null || value.isEmpty ? 'Pole wymagane' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                    labelText: 'Tytuł przelewu',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.title)),
                validator: (value) =>
                value == null || value.isEmpty ? 'Pole wymagane' : null,
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
                keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]?\d{0,2})'))
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Pole wymagane';
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null || amount <= 0)
                    return 'Niepoprawna kwota (musi być większa od 0)';
                  if (_selectedSenderAccount != null &&
                      amount > _selectedSenderAccount!.balance) {
                    return 'Niewystarczające środki na wybranym koncie';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientAddress1Controller,
                decoration: const InputDecoration(
                    labelText: 'Adres odbiorcy - linia 1 (opcjonalne)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _recipientAddress2Controller,
                decoration: const InputDecoration(
                    labelText: 'Adres odbiorcy - linia 2 (opcjonalne)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city_outlined)),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Wykonaj Przelew'),
                onPressed: (_isLoading ||
                    (_userAccounts.isEmpty &&
                        _selectedSenderAccount == null))
                    ? null
                    : _submitTransfer,
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