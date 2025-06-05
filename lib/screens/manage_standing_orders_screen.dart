import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/standing_order.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/standing_order_service.dart';

class ManageStandingOrdersScreen extends StatefulWidget {
  static const routeName = '/manage-standing-orders';

  const ManageStandingOrdersScreen({super.key});

  @override
  State<ManageStandingOrdersScreen> createState() => _ManageStandingOrdersScreenState();
}

class _ManageStandingOrdersScreenState extends State<ManageStandingOrdersScreen> {
  late Future<List<StandingOrder>> _standingOrdersFuture;
  List<StandingOrder> _standingOrders = [];
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadStandingOrders();
  }

  StandingOrderService _getStandingOrderService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StandingOrderService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _loadStandingOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAction = false;
      _standingOrdersFuture = _getStandingOrderService().getStandingOrders()
          .then((loadedOrders) {
        if (mounted) {
          setState(() {
            _standingOrders = loadedOrders;
          });
        }
        return loadedOrders;
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Błąd ładowania zleceń stałych: ${error.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
          );
          setState(() {
            _standingOrders = [];
          });
        }
        throw error;
      });
    });
  }

  Future<void> _deleteStandingOrder(int orderId) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potwierdzenie'),
        content: const Text('Czy na pewno chcesz dezaktywować to zlecenie stałe?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Dezaktywuj', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() { _isLoadingAction = true; });
      try {
        await _getStandingOrderService().deleteStandingOrder(orderId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zlecenie stałe dezaktywowane pomyślnie.'), backgroundColor: Colors.green),
        );
        _loadStandingOrders();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Błąd dezaktywowania zlecenia: ${e.toString().split(':').last.trim()}'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() { _isLoadingAction = false; });
        }
      }
    }
  }

  void _navigateToEditStandingOrderScreen([StandingOrder? order]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Funkcjonalność ${order == null ? "dodawania" : "edycji"} zlecenia wkrótce!')),
    );
  }


  String _formatDate(DateTime? date) {
    if (date == null) return 'Brak';
    return DateFormat('dd.MM.yyyy').format(date);
  }

  String _formatCurrency(double amount) {
    return '${amount.toStringAsFixed(2)} PLN';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zlecenia Stałe'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingAction ? null : _loadStandingOrders,
            tooltip: 'Odśwież zlecenia',
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<StandingOrder>>(
            future: _standingOrdersFuture,
            builder: (ctx, snapshot) {
              if (_standingOrders.isNotEmpty) {
                return ListView.builder(
                  itemCount: _standingOrders.length,
                  itemBuilder: (ctx, index) {
                    final order = _standingOrders[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          order.isActive ? Icons.event_repeat_rounded : Icons.event_busy_rounded,
                          color: order.isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                          size: 30,
                        ),
                        title: Text(order.transferTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Odbiorca: ${order.recipientName}'),
                            Text('Nr konta: ${order.targetAccountNumber}'),
                            Text('Kwota: ${_formatCurrency(order.amount)} (${order.frequency})'),
                            Text('Start: ${_formatDate(order.startDate)} | Następne: ${_formatDate(order.nextExecutionDate)}'),
                            if (order.endDate != null) Text('Koniec: ${_formatDate(order.endDate)}'),
                            Text('Status: ${order.isActive ? "Aktywne" : "Nieaktywne"}', style: TextStyle(fontWeight: FontWeight.w500, color: order.isActive ? Colors.green.shade700 : Colors.orange.shade700)),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              _navigateToEditStandingOrderScreen(order);
                            } else if (value == 'deactivate') {
                              _deleteStandingOrder(order.id);
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: Text('Edytuj'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'deactivate',
                              child: Text('Dezaktywuj', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                        isThreeLine: true,
                      ),
                    );
                  },
                );
              } else if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              } else if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Błąd ładowania zleceń stałych: ${snapshot.error.toString().split(':').last.trim()}',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Brak zdefiniowanych zleceń stałych.', style: TextStyle(fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Dodaj nowe zlecenie'),
                        onPressed: () => _navigateToEditStandingOrderScreen(),
                      )
                    ],
                  ),
                );
              }
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditStandingOrderScreen(),
        tooltip: 'Dodaj nowe zlecenie stałe',
        child: const Icon(Icons.add),
      ),
    );
  }
}