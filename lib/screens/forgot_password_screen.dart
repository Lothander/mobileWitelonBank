import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  static const routeName = '/forgot-password';

  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  bool _isLoading = false;
  String? _feedbackMessage;
  bool _isSuccess = false;

  Future<void> _submitRequest() async {
    final isValid = _formKey.currentState?.validate();
    if (isValid == null || !isValid) {
      return;
    }
    _formKey.currentState?.save();

    setState(() {
      _isLoading = true;
      _feedbackMessage = null;
      _isSuccess = false;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final String message = await authService.requestPasswordReset(_email);

    if (mounted) {
      setState(() {
        _isLoading = false;
        _feedbackMessage = message;
        if (message.toLowerCase().contains('wysłano') ||
            message.toLowerCase().contains('sent') ||
            message.toLowerCase().contains('sprawdź email') ||
            message.toLowerCase().contains('check your email') ||
            message
                .toLowerCase()
                .contains('link do resetowania hasła został wysłany') ||
            message.toLowerCase().contains('jeśli użytkownik istnieje')) {
          _isSuccess = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Resetowanie Hasła'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(Icons.lock_reset,
                    size: 60, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 20),
                const Text(
                  'Wprowadź swój adres email powiązany z kontem. Jeśli konto istnieje, wyślemy na nie instrukcję resetowania hasła.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('email_reset_password_input'),
                  validator: (value) {
                    if (value == null ||
                        value.isEmpty ||
                        !value.contains('@')) {
                      return 'Proszę podać poprawny adres email.';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    _email = value ?? '';
                  },
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: const Text('Wyślij Żądanie'),
                  ),
                if (_feedbackMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(
                      _feedbackMessage!,
                      style: TextStyle(
                        color: _isSuccess
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                if (_isSuccess)
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Wróć do logowania'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}