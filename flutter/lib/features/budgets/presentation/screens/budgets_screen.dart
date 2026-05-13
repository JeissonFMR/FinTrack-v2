import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/budgets_provider.dart';

class BudgetsScreen extends ConsumerWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetsAsync = ref.watch(budgetsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Presupuestos')),
      body: budgetsAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return const Center(
              child: Text(
                'Sin presupuestos aún',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(budgetsProvider),
            color: AppColors.primary,
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: budgets.length,
              separatorBuilder: (_, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _BudgetCard(budget: budgets[i]),
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

class _BudgetCard extends StatelessWidget {
  final dynamic budget;
  const _BudgetCard({required this.budget});

  @override
  Widget build(BuildContext context) {
    final category = budget['category'] as Map;
    final amount = (budget['amount'] as num).toDouble();
    final spent = (budget['spent'] as num?)?.toDouble() ?? 0;
    final percentage = (budget['percentage'] as num?)?.toInt() ?? 0;
    final color = _parseColor(category['color'] as String? ?? '#6366F1');

    final isOver = percentage >= 100;
    final isAlert = percentage >= 80 && !isOver;
    final barColor = isOver ? AppColors.expense : isAlert ? Colors.orange : AppColors.income;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tag, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  category['name'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
              ),
              Text(
                '$percentage%',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: isOver ? AppColors.expense : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (percentage / 100).clamp(0.0, 1.0),
              backgroundColor: AppColors.divider,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gastado: ${Formatters.currency(spent, symbol: '\$')}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              Text(
                'de ${Formatters.currency(amount, symbol: '\$')}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final h = hex.replaceAll('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
