import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/screens/forgot_password_screen.dart';

enum LoginFormState { enterCredentials, enter2FACode }

class LoginScreen extends StatefulWidget {
  static const routeName = '/login';
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String _email = '';
  String _password = '';
  String _twoFactorCode = '';
  bool _isLoading = false;
  String? _errorMessage;

  LoginFormState _formState = LoginFormState.enterCredentials;
  String? _emailFor2FA;

  Future<void> _handleLoginStep1() async {
    print("DEBUG: _handleLoginStep1 CALLED");

    if (!_formKey.currentState!.validate()) {
      print("DEBUG: Form validation FAILED in _handleLoginStep1");
      return;
    }
    _formKey.currentState!.save();
    print("DEBUG: Form saved in _handleLoginStep1. Email: $_email, Password: $_password");

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    print("DEBUG: Calling authService.loginStep1Request2FACode...");
    final result = await authService.loginStep1Request2FACode(_email, _password);
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (result.status == LoginStep1ResultStatus.success) {
        _formState = LoginFormState.enter2FACode;
        _emailFor2FA = result.email;
        _errorMessage = result.message;
        _formKey.currentState?.reset();
      } else {
        _errorMessage = result.message ?? 'Wystąpił nieznany błąd.';
      }
    });
  }

  Future<void> _handleLoginStep2() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    if (_emailFor2FA == null) {
      setState(() {
        _errorMessage = "Błąd: Email do weryfikacji 2FA nie jest ustawiony.";
        _formState = LoginFormState.enterCredentials;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await authService.loginStep2Verify2FACode(_emailFor2FA!, _twoFactorCode);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage = 'Nieprawidłowy kod weryfikacyjny lub wystąpił błąd.';
      }
    });
  }

  void _switchToCredentialsForm() {
    setState(() {
      _formState = LoginFormState.enterCredentials;
      _errorMessage = null;
      _emailFor2FA = null;
      _formKey.currentState?.reset();
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_formState == LoginFormState.enterCredentials
            ? 'Witelon Bank - Logowanie'
            : 'Weryfikacja Dwuetapowa'),
        leading: _formState == LoginFormState.enter2FACode
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _switchToCredentialsForm,
          tooltip: 'Anuluj weryfikację',
        )
            : null,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  _formState == LoginFormState.enterCredentials
                      ? Icons.account_balance
                      : Icons.security,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 20),

                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: _formState == LoginFormState.enter2FACode && _errorMessage!.toLowerCase().contains("wysłano") ? Colors.green.shade700 : Colors.red.shade700),
                      textAlign: TextAlign.center,
                    ),
                  ),

                if (_formState == LoginFormState.enterCredentials) ...[
                  TextFormField(
                    key: const ValueKey('email_login'),
                    initialValue: _email,
                    validator: (value) {
                      if (value == null || value.isEmpty || !value.contains('@')) {
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
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('password_login'),
                    validator: (value) {
                      if (value == null || value.isEmpty || value.length < 5) { // Dostosuj długość hasła, jeśli API ma inne wymagania
                        return 'Hasło musi mieć co najmniej 5 znaków.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _password = value ?? '';
                    },
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Hasło',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : () {
                        Navigator.of(context).pushNamed(ForgotPasswordScreen.routeName);
                      },
                      child: const Text('Zapomniałem hasła'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Wprowadź kod weryfikacyjny wysłany na adres: ${_emailFor2FA ?? "Twój email"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    key: const ValueKey('2fa_code'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Proszę podać kod weryfikacyjny.';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      _twoFactorCode = value ?? '';
                    },
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'Kod Weryfikacyjny',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                if (_isLoading)
                  const CircularProgressIndicator()
                else
                  ElevatedButton(
                    onPressed: _formState == LoginFormState.enterCredentials
                        ? _handleLoginStep1
                        : _handleLoginStep2,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                    child: Text(_formState == LoginFormState.enterCredentials
                        ? 'Dalej'
                        : 'Zweryfikuj Kod'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}