import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/screens/login_screen.dart';
import 'package:mobile_witelon_bank/screens/dashboard_screen.dart';
import 'package:mobile_witelon_bank/screens/forgot_password_screen.dart';
import 'package:mobile_witelon_bank/screens/transaction_history_screen.dart';
import 'package:mobile_witelon_bank/screens/transfer_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_cards_screen.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/screens/manage_standing_orders_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (ctx) => AuthService(),
      child: MaterialApp(
        title: 'Witelon Bank',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: Consumer<AuthService>(
          builder: (ctx, authService, _) =>
          authService.isAuthenticated ? const DashboardScreen() : const LoginScreen(),
        ),
        routes: {
          LoginScreen.routeName: (ctx) => const LoginScreen(),
          DashboardScreen.routeName: (ctx) => const DashboardScreen(),
          ForgotPasswordScreen.routeName: (ctx) => const ForgotPasswordScreen(),
          TransferScreen.routeName: (ctx) => const TransferScreen(),
          ManageStandingOrdersScreen.routeName: (ctx) => const ManageStandingOrdersScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == TransactionHistoryScreen.routeName) {
            final args = settings.arguments;
            if (args is BankAccount) {
              return MaterialPageRoute(
                builder: (context) {
                  return TransactionHistoryScreen(account: args);
                },
              );
            }
            print("Błąd nawigacji do TransactionHistoryScreen: Nieprawidłowe argumenty.");
            return _errorRoute("Błąd: Nie udało się załadować historii transakcji z powodu braku danych konta.");
          } else if (settings.name == ManageCardsScreen.routeName) {
            final args = settings.arguments;
            if (args is BankAccount) {
              return MaterialPageRoute(
                builder: (context) {
                  return ManageCardsScreen(account: args);
                },
              );
            }
            print("Błąd nawigacji do ManageCardsScreen: Nieprawidłowe argumenty.");
            return _errorRoute("Błąd: Nie udało się załadować zarządzania kartami z powodu braku danych konta.");
          }
          return null;
        },
      ),
    );
  }

  static MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text("Błąd Nawigacji")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}