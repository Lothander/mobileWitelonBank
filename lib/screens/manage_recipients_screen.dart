import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_witelon_bank/models/saved_recipient.dart';
import 'package:mobile_witelon_bank/services/auth_service.dart';
import 'package:mobile_witelon_bank/services/recipient_service.dart';
import 'package:mobile_witelon_bank/screens/edit_recipient_screen.dart';

class ManageRecipientsScreen extends StatefulWidget {
  static const routeName = '/manage-recipients';

  const ManageRecipientsScreen({super.key});

  @override
  State<ManageRecipientsScreen> createState() => _ManageRecipientsScreenState();
}

class _ManageRecipientsScreenState extends State<ManageRecipientsScreen> {
  late Future<List<SavedRecipient>> _recipientsFuture;
  List<SavedRecipient> _recipients = [];
  bool _isLoadingAction = false;

  @override
  void initState() {
    super.initState();
    _loadRecipients();
  }

  RecipientService _getRecipientService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return RecipientService(
      apiBaseUrl: AuthService.apiBaseUrl,
      token: authService.token,
    );
  }

  Future<void> _loadRecipients() async {
    if (!mounted) return;
    setState(() {
      _isLoadingAction = false;
      _recipientsFuture = _getRecipientService().getSavedRecipients().then((loadedRecipients) {
        if (mounted) {
          setState(() {
            _recipients = loadedRecipients;
          });
        }
        return loadedRecipients;
      }).catchError((error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Błąd ładowania odbiorców: ${error.toString().split(':').last.trim()}'),
                backgroundColor: Colors.red),
          );
          setState(() {
            _recipients = [];
          });
        }
        throw error;
      });
    });
  }

  Future<void> _deleteRecipient(int recipientId) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Potwierdzenie usunięcia'),
        content: const Text(
            'Czy na pewno chcesz usunąć tego zapisanego odbiorcę? Tej operacji nie można cofnąć.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Anuluj'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          TextButton(
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _isLoadingAction = true;
      });
      try {
        await _getRecipientService().deleteSavedRecipient(recipientId);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Odbiorca usunięty pomyślnie.'),
              backgroundColor: Colors.green),
        );
        _loadRecipients();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Błąd usuwania odbiorcy: ${e.toString().split(':').last.trim()}'),
              backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingAction = false;
          });
        }
      }
    }
  }

  void _navigateToEditRecipientScreen([SavedRecipient? recipient]) async {
    final result = await Navigator.of(context).pushNamed(
      EditRecipientScreen.routeName,
      arguments: recipient,
    );

    if (result == true && mounted) {
      _loadRecipients();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zapisani Odbiorcy'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoadingAction ? null : _loadRecipients,
            tooltip: 'Odśwież listę odbiorców',
          ),
        ],
      ),
      body: Stack(
        children: [
          FutureBuilder<List<SavedRecipient>>(
            future: _recipientsFuture,
            builder: (ctx, snapshot) {
              Widget content;
              if (_recipients.isNotEmpty) {
                content = ListView.builder(
                  itemCount: _recipients.length,
                  itemBuilder: (ctx, index) {
                    final recipient = _recipients[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      elevation: 2,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            recipient.definedName.isNotEmpty
                                ? recipient.definedName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer),
                          ),
                        ),
                        title: Text(recipient.definedName,
                            style:
                            const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(recipient.actualRecipientName,
                                style: TextStyle(color: Colors.grey[700])),
                            Text(recipient.accountNumber,
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600])),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _navigateToEditRecipientScreen(recipient);
                            } else if (value == 'delete') {
                              _deleteRecipient(recipient.id);
                            }
                          },
                          itemBuilder: (BuildContext context) =>
                          <PopupMenuEntry<String>>[
                            const PopupMenuItem<String>(
                              value: 'edit',
                              child: ListTile(
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edytuj')),
                            ),
                            const PopupMenuItem<String>(
                              value: 'delete',
                              child: ListTile(
                                  leading: Icon(Icons.delete_outline,
                                      color: Colors.red),
                                  title: Text('Usuń',
                                      style: TextStyle(color: Colors.red))),
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
                      'Błąd ładowania zapisanych odbiorców: ${snapshot.error.toString().split(':').last.trim()}',
                      style: const TextStyle(color: Colors.red, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              } else {
                content = Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people_outline,
                          size: 60, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      const Text('Brak zapisanych odbiorców.',
                          style: TextStyle(fontSize: 16, color: Colors.grey)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Dodaj pierwszego odbiorcę'),
                        onPressed: () => _navigateToEditRecipientScreen(),
                      )
                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToEditRecipientScreen(),
        tooltip: 'Dodaj nowego odbiorcę',
        child: const Icon(Icons.add),
      ),
    );
  }
}