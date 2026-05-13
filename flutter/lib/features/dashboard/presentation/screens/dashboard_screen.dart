import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final recent = ref.watch(recentTransactionsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(recentTransactionsProvider);
          },
          color: AppColors.primary,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Header(ref: ref),
                      const SizedBox(height: 24),
                      summary.when(
                        data: (data) => _SummaryCard(data: data),
                        loading: () => const _SummaryCardSkeleton(),
                        error: (err, st) => const _ErrorCard(),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Últimos movimientos',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              recent.when(
                data: (txs) => txs.isEmpty
                    ? const SliverToBoxAdapter(child: _EmptyTransactions())
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => _TransactionTile(tx: txs[i]),
                          childCount: txs.length,
                        ),
                      ),
                loading: () => const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )),
                ),
                error: (err, st) => const SliverToBoxAdapter(child: _ErrorCard()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                sliver: SliverToBoxAdapter(
                  child: TextButton(
                    onPressed: () => context.go('/transactions'),
                    child: const Text('Ver todos los movimientos'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/transactions/add'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final WidgetRef ref;
  const _Header({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const Text(
              'FinanzasJM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        IconButton(
          onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
          icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 18) return 'Buenas tardes';
    return 'Buenas noches';
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map? ?? {};
    final accounts = data['accounts'] as Map? ?? {};
    final totalBalance = (accounts['totalBalance'] as num?)?.toDouble() ?? 0;
    final income = (summary['totalIncome'] as num?)?.toDouble() ?? 0;
    final expenses = (summary['totalExpenses'] as num?)?.toDouble() ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Patrimonio total',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.currency(totalBalance, symbol: '\$'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Ingresos', amount: income, isIncome: true)),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(label: 'Gastos', amount: expenses, isIncome: false)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final bool isIncome;
  const _MiniStat({required this.label, required this.amount, required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
            color: isIncome ? AppColors.income : AppColors.expense,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(
                  Formatters.currency(amount, symbol: '\$'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final dynamic tx;
  const _TransactionTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx['type'] == 'INCOME';
    final isTransfer = tx['type'] == 'TRANSFER';
    final amount = (tx['amount'] as num).toDouble();
    final category = tx['category'];
    final date = DateTime.parse(tx['date']);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
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
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx['description'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        category != null ? category['name'] : Formatters.shortDate(date),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${isIncome ? '+' : isTransfer ? '' : '-'}${Formatters.currency(amount, symbol: '\$')}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: isIncome ? AppColors.income : isTransfer ? AppColors.primary : AppColors.expense,
                      ),
                    ),
                    Text(
                      Formatters.shortDate(date),
                      style: const TextStyle(color: AppColors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
        ],
      ),
    );
  }
}

class _SummaryCardSkeleton extends StatelessWidget {
  const _SummaryCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        color: AppColors.border,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(40),
      child: Center(
        child: Text(
          'Sin movimientos este mes',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Text('Error cargando datos', style: TextStyle(color: AppColors.expense)),
    );
  }
}
