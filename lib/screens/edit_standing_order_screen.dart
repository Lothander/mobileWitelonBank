import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/standing_order.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/account_service.dart';
import 'package:mobile_witelon_bank/services/standing_order_service.dart';

class EditStandingOrderScreen extends StatefulWidget {
  static const routeName = '/edit-standing-order';

  final StandingOrder? existingOrder;

  const EditStandingOrderScreen({super.key, this.existingOrder});

  bool get isEditing => existingOrder != null;

  @override
  State<EditStandingOrderScreen> createState() => _EditStandingOrderScreenState();
}

class _EditStandingOrderScreenState extends State<EditStandingOrderScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  List<BankAccount> _userAccounts = [];
  BankAccount? _selectedSourceAccount;
  final _targetAccountController = TextEditingController();
  final _recipientNameController = TextEditingController();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedFrequency;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isActive = true;
  final List<String> _frequencyOptions = ['miesiecznie', 'tygodniowo', 'rocznie', 'codziennie'];

  @override
  void initState() {
    super.initState();
    _loadUserAccounts();

    if (widget.isEditing && widget.existingOrder != null) {
      final order = widget.existingOrder!;
      _targetAccountController.text = order.targetAccountNumber;
      _recipientNameController.text = order.recipientName;
      _titleController.text = order.transferTitle;
      _amountController.text = order.amount.toStringAsFixed(2).replaceAll('.', ',');
      if (_frequencyOptions.contains(order.frequency)) {
        _selectedFrequency = order.frequency;
      } else {
        _selectedFrequency = null;
      }
      _startDate = order.startDate;
      _endDate = order.endDate;
      _isActive = order.isActive;
    } else {
      _startDate = DateTime.now().add(const Duration(days: 1));
    }
  }

  StandingOrderService _getStandingOrderService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StandingOrderService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _loadUserAccounts() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _feedbackMessage = null; });
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
              if (widget.isEditing && widget.existingOrder != null) {
                try {
                  _selectedSourceAccount = _userAccounts.firstWhere(
                          (acc) => acc.id == widget.existingOrder!.sourceAccountId
                  );
                } catch (e) {
                  _selectedSourceAccount = _userAccounts[0];
                  print("Konto źródłowe (${widget.existingOrder!.sourceAccountId}) z edytowanego zlecenia nie znalezione, ustawiono pierwsze dostępne.");
                }
              } else {
                _selectedSourceAccount = _userAccounts[0];
              }
            } else {
              _selectedSourceAccount = null;
            }
            _isLoading = false;
          });
        }
      } else {
        throw Exception("Użytkownik niezalogowany.");
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _feedbackMessage = "Błąd ładowania kont: ${error.toString().split(':').last.trim()}";
          _userAccounts = [];
          _selectedSourceAccount = null;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    DateTime initialDatePickerDate = (isStartDate ? _startDate : _endDate) ?? DateTime.now();
    DateTime firstDatePickerDate;

    if (isStartDate) {
      firstDatePickerDate = (widget.isEditing && widget.existingOrder != null && widget.existingOrder!.startDate.isBefore(DateTime.now()))
          ? widget.existingOrder!.startDate
          : DateTime.now();
      if (initialDatePickerDate.isBefore(firstDatePickerDate)) {
        initialDatePickerDate = firstDatePickerDate;
      }
    } else {
      firstDatePickerDate = _startDate ?? DateTime.now();
      if (initialDatePickerDate.isBefore(firstDatePickerDate)) {
        initialDatePickerDate = firstDatePickerDate;
      }
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDatePickerDate,
      firstDate: firstDatePickerDate,
      lastDate: DateTime(2101),
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(_startDate!)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedSourceAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać konto źródłowe.'), backgroundColor: Colors.red));
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać datę startu.'), backgroundColor: Colors.red));
      return;
    }
    if (_selectedFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Proszę wybrać częstotliwość.'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isLoading = true; _feedbackMessage = null; _isSuccess = false; });

    final double amount = double.parse(_amountController.text.replaceAll(',', '.'));

    final orderDataForSubmission = StandingOrder(
      id: widget.isEditing ? widget.existingOrder!.id : 0,
      userId: widget.isEditing ? widget.existingOrder!.userId : 0,
      sourceAccountId: _selectedSourceAccount!.id,
      targetAccountNumber: _targetAccountController.text,
      recipientName: _recipientNameController.text,
      transferTitle: _titleController.text,
      amount: amount,
      frequency: _selectedFrequency!,
      startDate: _startDate!,
      endDate: _endDate,
      isActive: _isActive,
      nextExecutionDate: widget.isEditing ? widget.existingOrder!.nextExecutionDate : DateTime.now(),
      createdAt: widget.isEditing ? widget.existingOrder!.createdAt : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final service = _getStandingOrderService();
      String successMessage;

      if (widget.isEditing) {
        await service.updateStandingOrder(widget.existingOrder!.id, orderDataForSubmission);
        successMessage = 'Zlecenie stałe zaktualizowane pomyślnie.';
      } else {
        await service.createStandingOrder(orderDataForSubmission);
        successMessage = 'Zlecenie stałe utworzone pomyślnie.';
      }

      if (mounted) {
        setState(() { _isLoading = false; _isSuccess = true; _feedbackMessage = successMessage; });
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _feedbackMessage = "Błąd: ${error.toString().split(':').last.trim()}";
        });
      }
    }
  }

  @override
  void dispose() {
    _targetAccountController.dispose();
    _recipientNameController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edytuj Zlecenie Stałe' : 'Nowe Zlecenie Stałe'),
      ),
      body: _isLoading && _userAccounts.isEmpty
          ? const Center(child: CircularProgressIndicator())
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
                    style: TextStyle(color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              if (_userAccounts.isNotEmpty)
                DropdownButtonFormField<BankAccount>(
                  value: _selectedSourceAccount,
                  decoration: const InputDecoration(labelText: 'Z konta', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance_wallet)),
                  items: _userAccounts.map((BankAccount account) {
                    return DropdownMenuItem<BankAccount>(
                      value: account,
                      child: Text('${account.accountNumber} (${account.balance.toStringAsFixed(2)} ${account.currency})'),
                    );
                  }).toList(),
                  onChanged: (BankAccount? newValue) => setState(() => _selectedSourceAccount = newValue),
                  validator: (value) => value == null ? 'Wybierz konto' : null,
                )
              else if (!_isLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _feedbackMessage == null && _userAccounts.isEmpty ? 'Brak dostępnych kont.' : (_feedbackMessage ?? ''),
                    style: TextStyle(color: _feedbackMessage == null ? Colors.grey : Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 16),
              TextFormField(
                controller: _targetAccountController,
                decoration: const InputDecoration(labelText: 'Nr konta odbiorcy (IBAN)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.account_balance)),
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
                  suffixText: _selectedSourceAccount?.currency ?? 'PLN',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*([.,]?\d{0,2})'))],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Pole wymagane';
                  final amount = double.tryParse(value.replaceAll(',', '.'));
                  if (amount == null || amount <= 0) return 'Niepoprawna kwota (musi być większa od 0)';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedFrequency,
                decoration: const InputDecoration(labelText: 'Częstotliwość', border: OutlineInputBorder(), prefixIcon: Icon(Icons.event_repeat)),
                items: _frequencyOptions.map((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
                onChanged: (String? newValue) => setState(() => _selectedFrequency = newValue),
                validator: (value) => value == null ? 'Wybierz częstotliwość' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: Colors.grey.shade400)),
                title: Text(_startDate == null ? 'Wybierz datę startu' : 'Data startu: ${DateFormat('dd.MM.yyyy').format(_startDate!)}'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () => _selectDate(context, true), // Na razie bez blokady edycji daty startu
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: Colors.grey.shade400)),
                title: Text(_endDate == null ? 'Data zakończenia (opcjonalnie)' : 'Data zakończenia: ${DateFormat('dd.MM.yyyy').format(_endDate!)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_endDate != null)
                      IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        tooltip: 'Wyczyść datę zakończenia',
                        onPressed: () => setState(() => _endDate = null),
                      ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Zlecenie aktywne'),
                value: _isActive,
                onChanged: (bool value) => setState(() => _isActive = value),
                activeColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.0), side: BorderSide(color: Colors.grey.shade400)),
                contentPadding: const EdgeInsets.only(left:16.0, right: 6.0),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15)
                ),
                child: Text(widget.isEditing ? 'Zapisz Zmiany' : 'Utwórz Zlecenie'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}