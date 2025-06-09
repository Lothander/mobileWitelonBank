import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/screens/login_screen.dart';
import 'package:mobile_witelon_bank/screens/dashboard_screen.dart';
import 'package:mobile_witelon_bank/screens/forgot_password_screen.dart';
import 'package:mobile_witelon_bank/screens/transaction_history_screen.dart';
import 'package:mobile_witelon_bank/screens/transfer_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_cards_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_standing_orders_screen.dart';
import 'package:mobile_witelon_bank/screens/edit_standing_order_screen.dart';
import 'package:mobile_witelon_bank/screens/edit_recipient_screen.dart';
import 'package:mobile_witelon_bank/screens/manage_recipients_screen.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/standing_order.dart';
import 'package:mobile_witelon_bank/models/saved_recipient.dart';

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
          builder: (ctx, authService, _) => authService.isAuthenticated
              ? const DashboardScreen()
              : const LoginScreen(),
        ),
        routes: {
          LoginScreen.routeName: (ctx) => const LoginScreen(),
          DashboardScreen.routeName: (ctx) => const DashboardScreen(),
          ForgotPasswordScreen.routeName: (ctx) => const ForgotPasswordScreen(),
          TransferScreen.routeName: (ctx) => const TransferScreen(),
          ManageStandingOrdersScreen.routeName: (ctx) =>
          const ManageStandingOrdersScreen(),
          ManageRecipientsScreen.routeName: (ctx) =>
          const ManageRecipientsScreen(),
        },
        onGenerateRoute: (settings) {
          if (settings.name == TransactionHistoryScreen.routeName) {
            final args = settings.arguments;
            if (args is BankAccount) {
              return MaterialPageRoute(
                  builder: (context) => TransactionHistoryScreen(account: args));
            }
            return _errorRoute(
                "Błąd: Nieprawidłowe dane konta dla historii transakcji.");
          }

          if (settings.name == ManageCardsScreen.routeName) {
            final args = settings.arguments;
            if (args is BankAccount) {
              return MaterialPageRoute(
                  builder: (context) => ManageCardsScreen(account: args));
            }
            return _errorRoute(
                "Błąd: Nieprawidłowe dane konta dla zarządzania kartami.");
          }

          if (settings.name == EditStandingOrderScreen.routeName) {
            final StandingOrder? existingOrder =
            settings.arguments as StandingOrder?;
            return MaterialPageRoute(
                builder: (context) =>
                    EditStandingOrderScreen(existingOrder: existingOrder));
          }

          if (settings.name == EditRecipientScreen.routeName) {
            final SavedRecipient? existingRecipient =
            settings.arguments as SavedRecipient?;
            return MaterialPageRoute(
                builder: (context) =>
                    EditRecipientScreen(existingRecipient: existingRecipient));
          }

          return _errorRoute("Nie znaleziono strony: ${settings.name}");
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
            child: Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red, fontSize: 16)),
          ),
        ),
      ),
    );
  }
}