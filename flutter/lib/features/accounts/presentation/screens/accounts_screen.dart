import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      body: accountsAsync.when(
        data: (accounts) {
          final total = accounts.fold<double>(
            0,
            (sum, a) => sum + (a['balance'] as num).toDouble(),
          );
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountsListProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _TotalCard(total: total),
                const SizedBox(height: 24),
                const Text(
                  'Mis cuentas',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                ...accounts.map((a) => _AccountCard(account: a)),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(
          child: Text('$err', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Patrimonio total',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 6),
          Text(
            Formatters.currency(total, symbol: '\$'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final dynamic account;
  const _AccountCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final balance = (account['balance'] as num).toDouble();
    final color = _parseColor(account['color'] as String? ?? '#6366F1');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Text(
                  _typeLabel(account['type'] as String),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            Formatters.currency(balance, symbol: '\$'),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }

  String _typeLabel(String type) {
    const labels = {
      'CASH': 'Efectivo',
      'BANK': 'Banco',
      'CREDIT_CARD': 'Tarjeta de crédito',
      'DIGITAL_WALLET': 'Billetera digital',
      'INVESTMENT': 'Inversión',
      'SAVINGS': 'Ahorros',
      'LOAN': 'Préstamo',
    };
    return labels[type] ?? type;
  }
}
