class BalanceCard extends StatelessWidget {
  final double balance;
  const BalanceCard(this.balance);
  @override
  Widget build(BuildContext context) {
    return Card(child: Text('Saldo: $balance PLN'));
  }
}