import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/saved_recipient.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/recipient_service.dart';

class EditRecipientScreen extends StatefulWidget {
  static const routeName = '/edit-recipient';

  final SavedRecipient? existingRecipient;

  const EditRecipientScreen({super.key, this.existingRecipient});

  bool get isEditing => existingRecipient != null;

  @override
  State<EditRecipientScreen> createState() => _EditRecipientScreenState();
}

class _EditRecipientScreenState extends State<EditRecipientScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  final _definedNameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _actualRecipientNameController = TextEditingController();
  final _addressLine1Controller = TextEditingController();
  final _addressLine2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.existingRecipient != null) {
      final recipient = widget.existingRecipient!;
      _definedNameController.text = recipient.definedName;
      _accountNumberController.text = recipient.accountNumber;
      _actualRecipientNameController.text = recipient.actualRecipientName;
      _addressLine1Controller.text = recipient.addressLine1 ?? '';
      _addressLine2Controller.text = recipient.addressLine2 ?? '';
    }
  }

  RecipientService _getRecipientService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return RecipientService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    final recipientData = SavedRecipient(
      id: widget.isEditing ? widget.existingRecipient!.id : 0,
      userId: widget.isEditing ? widget.existingRecipient!.userId : null,
      definedName: _definedNameController.text.trim(),
      accountNumber: _accountNumberController.text.trim(),
      actualRecipientName: _actualRecipientNameController.text.trim(),
      addressLine1: _addressLine1Controller.text.trim().isNotEmpty
          ? _addressLine1Controller.text.trim()
          : null,
      addressLine2: _addressLine2Controller.text.trim().isNotEmpty
          ? _addressLine2Controller.text.trim()
          : null,
      createdAt: widget.isEditing
          ? widget.existingRecipient!.createdAt ?? DateTime.now()
          : DateTime.now(),
      updatedAt: DateTime.now(),
    );

    try {
      final service = _getRecipientService();
      String successMessage;

      if (widget.isEditing) {
        await service.updateSavedRecipient(
            widget.existingRecipient!.id, recipientData);
        successMessage = 'Odbiorca zaktualizowany pomyślnie.';
      } else {
        await service.addSavedRecipient(recipientData);
        successMessage = 'Odbiorca dodany pomyślnie.';
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSuccess = true;
          _feedbackMessage = successMessage;
        });
        await Future.delayed(const Duration(seconds: 1));
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
    _definedNameController.dispose();
    _accountNumberController.dispose();
    _actualRecipientNameController.dispose();
    _addressLine1Controller.dispose();
    _addressLine2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edytuj Odbiorcę' : 'Dodaj Odbiorcę'),
      ),
      body: SingleChildScrollView(
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
                        fontWeight: FontWeight.w500,
                        fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
              TextFormField(
                controller: _definedNameController,
                decoration: const InputDecoration(
                    labelText: 'Nazwa własna odbiorcy (np. Mama, Czynsz)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_important_outline)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Pole wymagane';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _accountNumberController,
                decoration: const InputDecoration(
                    labelText: 'Numer konta odbiorcy (IBAN)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.account_balance)),
                keyboardType: TextInputType.text,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                  LengthLimitingTextInputFormatter(28),
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Pole wymagane';
                  if (!RegExp(r'^PL\d{2}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}\s?\d{4}$')
                      .hasMatch(value.replaceAll(' ', ''))) {
                    if (!RegExp(r'^PL\d{26}$').hasMatch(value)) {
                      return 'Niepoprawny format IBAN PL (PL + 26 cyfr)';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _actualRecipientNameController,
                decoration: const InputDecoration(
                    labelText: 'Rzeczywista nazwa odbiorcy (np. Jan Kowalski)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline)),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return 'Pole wymagane';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine1Controller,
                decoration: const InputDecoration(
                    labelText: 'Adres - linia 1 (opcjonalne)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on_outlined)),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressLine2Controller,
                decoration: const InputDecoration(
                    labelText: 'Adres - linia 2 (opcjonalne)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_city_outlined)),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 15)),
                child: Text(
                    widget.isEditing ? 'Zapisz Zmiany' : 'Dodaj Odbiorcę'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}