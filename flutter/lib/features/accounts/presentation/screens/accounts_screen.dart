import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/accounts_provider.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(accountsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cuentas')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/accounts/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
      body: summaryAsync.when(
        data: (summary) {
          final accounts = summary['accounts'] as List? ?? [];
          final total = Formatters.decimal(summary['totalBalance']);

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(accountsSummaryProvider),
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              children: [
                _TotalCard(total: total),
                const SizedBox(height: 24),
                if (accounts.isEmpty)
                  const _EmptyAccounts()
                else ...[
                  const Text(
                    'Mis cuentas',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  ...accounts.map((a) => _AccountCard(account: a, ref: ref)),
                ],
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
  final WidgetRef ref;
  const _AccountCard({required this.account, required this.ref});

  @override
  Widget build(BuildContext context) {
    final balance = Formatters.decimal(account['balance']);
    final color = _hexColor(account['color'] as String? ?? '#18181B');

    final cardLast4 = account['cardLast4'] as String?;
    return GestureDetector(
      onTap: () => context.push('/accounts/edit',
          extra: Map<String, dynamic>.from(account as Map)),
      onLongPress: () => _showMenu(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
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
                    cardLast4 != null
                        ? '${_typeLabel(account['type'] as String)} · •••• $cardLast4'
                        : _typeLabel(account['type'] as String),
                    style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              Formatters.currency(balance, symbol: '\$'),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: balance < 0 ? AppColors.expense : context.colors.textPrimary,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right,
                size: 18, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar cuenta'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/accounts/edit', extra: Map<String, dynamic>.from(account as Map));
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined, color: AppColors.expense),
              title: const Text('Archivar cuenta', style: TextStyle(color: AppColors.expense)),
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('Archivar cuenta'),
                    content: Text('¿Archivar "${account['name']}"? Ya no aparecerá en tus cuentas activas.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(d);
                          ref.read(accountActionsProvider.notifier).archive(account['id'] as String);
                        },
                        style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                        child: const Text('Archivar'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
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

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: context.colors.textHint),
            const SizedBox(height: 12),
            Text('Sin cuentas aún',
                style: TextStyle(color: context.colors.textSecondary, fontSize: 15)),
            const SizedBox(height: 4),
            Text('Toca + para agregar tu primera cuenta',
                style: TextStyle(color: context.colors.textHint, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
