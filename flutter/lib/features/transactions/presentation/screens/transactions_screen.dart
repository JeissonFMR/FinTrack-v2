import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/transactions_provider.dart';

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txsAsync = ref.watch(transactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/transactions/add'),
          ),
        ],
      ),
      body: txsAsync.when(
        data: (data) {
          final txs = data['data'] as List;
          if (txs.isEmpty) {
            return const Center(
              child: Text(
                'Sin movimientos aún',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(transactionsProvider),
            color: AppColors.primary,
            child: ListView.separated(
              itemCount: txs.length,
              separatorBuilder: (_, i) => const Divider(height: 0, indent: 72),
              itemBuilder: (ctx, i) => _TxTile(tx: txs[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(
          child: Text('Error: $err', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final dynamic tx;
  const _TxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx['type'] == 'INCOME';
    final isTransfer = tx['type'] == 'TRANSFER';
    final amount = (tx['amount'] as num).toDouble();
    final category = tx['category'];
    final date = DateTime.parse(tx['date']);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isTransfer
              ? AppColors.primaryLight
              : isIncome
                  ? AppColors.incomeLight
                  : AppColors.expenseLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          isTransfer
              ? Icons.swap_horiz_rounded
              : isIncome
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
          size: 18,
          color: isTransfer
              ? AppColors.primary
              : isIncome
                  ? AppColors.income
                  : AppColors.expense,
        ),
      ),
      title: Text(
        tx['description'] ?? '',
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      ),
      subtitle: Text(
        '${category != null ? category['name'] + ' · ' : ''}${Formatters.date(date)}',
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
      ),
      trailing: Text(
        '${isIncome ? '+' : isTransfer ? '' : '-'}${Formatters.currency(amount, symbol: '\$')}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: isIncome
              ? AppColors.income
              : isTransfer
                  ? AppColors.primary
                  : AppColors.expense,
        ),
      ),
    );
  }
}
