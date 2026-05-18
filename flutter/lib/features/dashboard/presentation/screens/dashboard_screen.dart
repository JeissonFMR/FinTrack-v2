import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../debts/presentation/providers/debts_provider.dart';
import '../../../goals/presentation/providers/goals_provider.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(dashboardSummaryProvider);
    final recent = ref.watch(recentTransactionsProvider);
    final goalsAsync = ref.watch(goalsProvider);
    final debtsAsync = ref.watch(debtsProvider);
    final forecastAsync = ref.watch(forecastProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(recentTransactionsProvider);
            ref.invalidate(goalsProvider);
            ref.invalidate(debtsProvider);
            ref.invalidate(forecastProvider);
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
                      forecastAsync.when(
                        data: (data) => data.isEmpty
                            ? const SizedBox.shrink()
                            : Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: _ForecastCard(data: data),
                              ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickCard(
                              icon: Icons.flag_rounded,
                              label: 'Metas',
                              value: goalsAsync.when(
                                data: (goals) {
                                  final active = goals
                                      .where((g) => g['status'] != 'COMPLETED')
                                      .length;
                                  return '$active activa${active != 1 ? 's' : ''}';
                                },
                                loading: () => '...',
                                error: (err, st) => '—',
                              ),
                              color: AppColors.primary,
                              onTap: () => context.go('/goals'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickCard(
                              icon: Icons.account_balance_outlined,
                              label: 'Deudas',
                              value: debtsAsync.when(
                                data: (data) {
                                  final iOwe = (data['iOwe'] as num?)?.toDouble() ?? 0;
                                  return iOwe > 0
                                      ? 'Debo ${Formatters.currency(iOwe, symbol: '\$')}'
                                      : 'Sin deudas';
                                },
                                loading: () => '...',
                                error: (err, st) => '—',
                              ),
                              color: AppColors.expense,
                              onTap: () => context.go('/debts'),
                            ),
                          ),
                        ],
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
              style: TextStyle(color: context.colors.textSecondary, fontSize: 14),
            ),
            const Text(
              'FinanzasJM',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        IconButton(
          onPressed: () => context.push('/reports'),
          icon: Icon(Icons.bar_chart_rounded, color: context.colors.textSecondary),
        ),
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: Icon(Icons.person_outline_rounded, color: context.colors.textSecondary),
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

class _QuickCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  const _QuickCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 11)),
                  Text(value,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _SummaryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary = data['summary'] as Map? ?? {};
    final accounts = data['accounts'] as Map? ?? {};
    final totalBalance = Formatters.decimal(accounts['totalBalance']);
    final income = Formatters.decimal(summary['totalIncome']);
    final expenses = Formatters.decimal(summary['totalExpenses']);

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
    final amount = Formatters.decimal(tx['amount']);
    final category = tx['category'];
    final date = DateTime.parse(tx['date']);

    return InkWell(
      onTap: () => context.push('/transactions/edit',
          extra: Map<String, dynamic>.from(tx as Map)),
      child: Padding(
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
                        ? context.colors.primaryLight
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
                        style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
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
                      style: TextStyle(color: context.colors.textHint, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 0),
        ],
      ),
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
        color: context.colors.border,
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Center(
        child: Text(
          'Sin movimientos este mes',
          style: TextStyle(color: context.colors.textSecondary),
        ),
      ),
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ForecastCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final projected = (data['projectedTotal'] as num?)?.toDouble() ?? 0;
    final spent = (data['spentSoFar'] as num?)?.toDouble() ?? 0;
    final lastMonth = (data['lastMonthTotal'] as num?)?.toDouble() ?? 0;
    final dayOfMonth = (data['dayOfMonth'] as num?)?.toInt() ?? 0;
    final daysInMonth = (data['daysInMonth'] as num?)?.toInt() ?? 30;
    final delta = data['deltaVsLast'];
    final deltaNum = delta is num ? delta.toDouble() : null;

    // Si aún no hay datos del mes, no mostramos nada útil
    if (spent == 0 && dayOfMonth < 2) return const SizedBox.shrink();

    final isOverLast = deltaNum != null && deltaNum > 0;
    final accentColor = isOverLast ? AppColors.expense : AppColors.income;

    final remaining = projected - spent;

    return GestureDetector(
      onTap: () => _showInfoSheet(
          context, projected, spent, lastMonth, dayOfMonth, daysInMonth),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded,
                    size: 16, color: context.colors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Gasto total estimado del mes',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const Spacer(),
                Icon(Icons.info_outline,
                    size: 16, color: context.colors.textHint),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              Formatters.currency(projected, symbol: '\$'),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'al final del mes (día $dayOfMonth de $daysInMonth)',
              style: TextStyle(
                  fontSize: 12, color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            // Desglose visual: ya gastado + estimado restante = total
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ya gastado',
                        style: TextStyle(
                            fontSize: 10,
                            color: context.colors.textHint,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(spent, symbol: '\$'),
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Text('+',
                    style: TextStyle(
                        fontSize: 16, color: context.colors.textHint)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Faltaría gastar',
                        style: TextStyle(
                            fontSize: 10,
                            color: context.colors.textHint,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Formatters.currency(remaining, symbol: '\$'),
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (deltaNum != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOverLast
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isOverLast
                          ? '${Formatters.currency(deltaNum.abs(), symbol: '\$')} más que el mes pasado'
                          : '${Formatters.currency(deltaNum.abs(), symbol: '\$')} menos que el mes pasado',
                      style: TextStyle(
                        fontSize: 12,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Mes pasado: ${Formatters.currency(lastMonth, symbol: '\$')}',
                style:
                    TextStyle(fontSize: 11, color: context.colors.textHint),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showInfoSheet(
    BuildContext context,
    double projected,
    double spent,
    double lastMonth,
    int dayOfMonth,
    int daysInMonth,
  ) {
    final dailyAvg = dayOfMonth > 0 ? spent / dayOfMonth : 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.insights_rounded,
                      size: 22, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    '¿Qué es la proyección?',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Es una estimación del TOTAL que vas a haber gastado al terminar este mes, asumiendo que sigues al mismo ritmo. Incluye lo que ya gastaste + lo que se estima vas a gastar de hoy en adelante.',
                style: TextStyle(
                    color: ctx.colors.textSecondary, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),
              _InfoRow(
                label: 'Tu ritmo actual',
                value:
                    '${Formatters.currency(dailyAvg.toDouble(), symbol: '\$')}/día',
                description:
                    '${Formatters.currency(spent, symbol: '\$')} gastados en $dayOfMonth días',
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Estimado restante',
                value:
                    Formatters.currency((projected - spent).clamp(0, double.infinity), symbol: '\$'),
                description:
                    'Lo que se proyecta que gastarás los ${daysInMonth - dayOfMonth} días que quedan',
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: 'Total estimado del mes',
                value: Formatters.currency(projected, symbol: '\$'),
                description:
                    'Ya gastado + estimado restante (el número grande del card)',
              ),
              if (lastMonth > 0) ...[
                const SizedBox(height: 16),
                _InfoRow(
                  label: 'Comparativa',
                  value: Formatters.currency(lastMonth, symbol: '\$'),
                  description:
                      'Total gastado el mes pasado — para comparar tu ritmo',
                ),
              ],
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Si la proyección te parece alta, baja el ritmo en los días que quedan. Si es baja, tienes margen.',
                        style: TextStyle(
                            fontSize: 12,
                            color: ctx.colors.textSecondary,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Entendido'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String description;
  const _InfoRow({
    required this.label,
    required this.value,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      color: context.colors.textSecondary,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description,
                  style: TextStyle(
                      fontSize: 11, color: context.colors.textHint)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ],
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
