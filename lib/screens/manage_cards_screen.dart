import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/bank_account.dart';
import 'package:mobile_witelon_bank/models/payment_card.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/card_service.dart';

class ManageCardsScreen extends StatefulWidget {
  static const routeName = '/manage-cards';

  final BankAccount account;

  const ManageCardsScreen({super.key, required this.account});

  @override
  State<ManageCardsScreen> createState() => _ManageCardsScreenState();
}

class _ManageCardsScreenState extends State<ManageCardsScreen> {
  Future<List<PaymentCard>>? _cardsFuture;
  List<PaymentCard> _cards = [];
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadCards();
  }

  CardService _getCardService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return CardService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _loadCards() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAction = false;
      _cardsFuture = _getCardService().getCardsForAccount(widget.account.id)
          .then((loadedCards) {
        if (mounted) {
          setState(() {
            _cards = loadedCards;
          });
        }
        return loadedCards;
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd ładowania kart: ${error.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
          );
          setState(() {
            _cards = [];
          });
        }
        throw error;
      });
    });
  }

  Future<void> _toggleBlockCard(PaymentCard card) async {
    if (!mounted) return;
    setState(() { _isLoadingAction = true; });
    try {
      PaymentCard updatedCard;
      if (card.isBlocked) {
        updatedCard = await _getCardService().unblockCard(card.id);
      } else {
        updatedCard = await _getCardService().blockCard(card.id);
      }
      _updateCardInList(updatedCard);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Karta ${updatedCard.isBlocked ? "zablokowana" : "odblokowana"} pomyślnie.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoadingAction = false; });
      }
    }
  }

  Future<void> _changeDailyLimit(PaymentCard card) async {
    final newLimitString = await _showChangeLimitDialog(context, card);
    if (newLimitString != null && newLimitString.isNotEmpty) {
      final newLimitInt = int.tryParse(newLimitString);
      if (newLimitInt != null && newLimitInt >= 0) {
        if (!mounted) return;
        setState(() { _isLoadingAction = true; });
        try {
          final updatedCard = await _getCardService().changeDailyLimit(card.id, newLimitInt.toDouble());
          _updateCardInList(updatedCard);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Limit dzienny zmieniony pomyślnie.'), backgroundColor: Colors.green),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd zmiany limitu: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
          );
        } finally {
          if (mounted) {
            setState(() { _isLoadingAction = false; });
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Niepoprawna wartość limitu (musi być liczbą całkowitą nieujemną).'), backgroundColor: Colors.orange),
        );
      }
    }
  }

  Future<void> _changePaymentSettings(PaymentCard card, {bool? internet, bool? contactless}) async {
    bool changeInternet = internet != null;
    bool changeContactless = contactless != null;

    if (!changeInternet && !changeContactless) {
      return;
    }
    if (!mounted) return;
    setState(() { _isLoadingAction = true; });
    try {
      final updatedCard = await _getCardService().updatePaymentSettings(
        card.id,
        internetPayments: internet,
        contactlessPayments: contactless,
      );
      _updateCardInList(updatedCard);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ustawienia płatności zmienione pomyślnie.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Błąd zmiany ustawień: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() { _isLoadingAction = false; });
      }
    }
  }

  void _updateCardInList(PaymentCard updatedCard) {
    if (mounted) {
      setState(() {
        final index = _cards.indexWhere((c) => c.id == updatedCard.id);
        if (index != -1) {
          _cards[index] = updatedCard;
        } else {
          _loadCards();
        }
      });
    }
  }

  String _formatExpiryDate(DateTime date) {
    return DateFormat('MM/yy').format(date);
  }

  Future<String?> _showChangeLimitDialog(BuildContext context, PaymentCard card) async {
    final TextEditingController limitController = TextEditingController(
        text: card.dailyLimit.toInt().toString()
    );
    final String currency = widget.account.currency;

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Zmień dzienny limit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Obecny limit: ${card.dailyLimit.toInt()} $currency',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: InputDecoration(
                  labelText: 'Nowy limit',
                  suffixText: currency,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
            ),
            TextButton(
              child: const Text('Zmień'),
              onPressed: () {
                Navigator.of(dialogContext).pop(limitController.text);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showTogglePaymentSettingDialog(BuildContext context, PaymentCard card, String settingType) async {
    bool? enableSetting = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        String title = settingType == 'internet'
            ? 'Płatności Internetowe'
            : 'Płatności Zbliżeniowe';

        bool? currentSettingState;
        if (settingType == 'internet') {
          currentSettingState = card.internetPaymentsActive;
        } else if (settingType == 'contactless') {
          currentSettingState = card.contactlessPaymentsActive;
        }

        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              currentSettingState != null
                  ? Text('Aktualny stan: ${currentSettingState ? "Włączone" : "Wyłączone"}')
                  : const Text('Aktualny stan: Nieznany (odśwież listę kart)'),
              const SizedBox(height: 10),
              const Text('Wybierz nową opcję:'),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('WŁĄCZ'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
            TextButton(
              child: const Text('WYŁĄCZ'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              child: const Text('Anuluj'),
              onPressed: () => Navigator.of(dialogContext).pop(null),
            ),
          ],
        );
      },
    );

    if (enableSetting != null) {
      if (settingType == 'internet') {
        _changePaymentSettings(card, internet: enableSetting);
      } else if (settingType == 'contactless') {
        _changePaymentSettings(card, contactless: enableSetting);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Karty dla ${widget.account.accountNumber}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingAction ? null : _loadCards,
            tooltip: 'Odśwież listę kart',
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<PaymentCard>>(
            future: _cardsFuture,
            builder: (ctx, snapshot) {
              Widget content;

              if (_cards.isNotEmpty) {
                content = ListView.builder(
                  itemCount: _cards.length,
                  itemBuilder: (context, index) {
                    final card = _cards[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  card.maskedCardNumber,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5, fontFamily: 'monospace'),
                                ),
                                Icon(
                                  card.cardType.toLowerCase().contains('visa') ? Icons.payment :
                                  card.cardType.toLowerCase().contains('mastercard') ? Icons.payments_outlined : Icons.credit_card,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 30,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Ważna do: ${_formatExpiryDate(card.expiryDate)}', style: TextStyle(color: Colors.grey[700])),
                            Text('Typ: ${card.cardType}', style: TextStyle(color: Colors.grey[700])),
                            Text('Limit dzienny: ${card.dailyLimit.toInt()} ${widget.account.currency}', style: TextStyle(color: Colors.grey[700])),

                            if (card.internetPaymentsActive != null)
                              Text('Płatności internetowe: ${card.internetPaymentsActive! ? "Włączone" : "Wyłączone"}', style: TextStyle(color: Colors.grey[700]))
                            else
                              Text('Płatności internetowe: Nieznane', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),

                            if (card.contactlessPaymentsActive != null)
                              Text('Płatności zbliżeniowe: ${card.contactlessPaymentsActive! ? "Włączone" : "Wyłączone"}', style: TextStyle(color: Colors.grey[700]))
                            else
                              Text('Płatności zbliżeniowe: Nieznane', style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic)),

                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  card.isBlocked ? 'ZABLOKOWANA' : 'AKTYWNA',
                                  style: TextStyle(
                                    color: card.isBlocked ? Colors.redAccent : Colors.green.shade700,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.tune),
                                  tooltip: "Ustawienia płatności",
                                  onSelected: (value) {
                                    if (value == 'toggle_internet') {
                                      _showTogglePaymentSettingDialog(context, card, 'internet');
                                    } else if (value == 'toggle_contactless') {
                                      _showTogglePaymentSettingDialog(context, card, 'contactless');
                                    }
                                  },
                                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                    const PopupMenuItem<String>(
                                      value: 'toggle_internet',
                                      child: Text('Płatności internetowe'),
                                    ),
                                    const PopupMenuItem<String>(
                                      value: 'toggle_contactless',
                                      child: Text('Płatności zbliżeniowe'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const Divider(height: 24, thickness: 1),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: Icon(card.isBlocked ? Icons.lock_open_outlined : Icons.lock_outline),
                                  label: Text(card.isBlocked ? 'Odblokuj' : 'Zablokuj'),
                                  onPressed: _isLoadingAction ? null : () => _toggleBlockCard(card),
                                  style: TextButton.styleFrom(
                                    foregroundColor: card.isBlocked ? Colors.green.shade700 : Colors.redAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                TextButton.icon(
                                  icon: const Icon(Icons.speed_outlined),
                                  label: const Text('Zmień limit'),
                                  onPressed: _isLoadingAction ? null : () => _changeDailyLimit(card),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                content = const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                content = Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Błąd ładowania kart: ${snapshot.error.toString().split(':').last.trim()}',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              } else {
                content = const Center(
                  child: Text(
                    'Brak kart płatniczych dla tego konta.',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return content;
            },
          ),
          if (_isLoadingAction)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.15),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}