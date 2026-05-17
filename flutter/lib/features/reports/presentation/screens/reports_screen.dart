import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(reportPeriodProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Análisis')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(reportsSummaryProvider);
          ref.invalidate(monthlyEvolutionProvider);
        },
        color: AppColors.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          children: [
            _PeriodSelector(period: period, ref: ref),
            const SizedBox(height: 24),
            _ExpenseBreakdownCard(ref: ref),
            const SizedBox(height: 20),
            _MonthlyEvolutionCard(ref: ref),
          ],
        ),
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final ReportPeriod period;
  final WidgetRef ref;
  const _PeriodSelector({required this.period, required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PeriodChip(
          label: 'Este mes',
          selected: period == ReportPeriod.thisMonth,
          onTap: () => ref.read(reportPeriodProvider.notifier).state =
              ReportPeriod.thisMonth,
        ),
        const SizedBox(width: 8),
        _PeriodChip(
          label: 'Trimestre',
          selected: period == ReportPeriod.lastThreeMonths,
          onTap: () => ref.read(reportPeriodProvider.notifier).state =
              ReportPeriod.lastThreeMonths,
        ),
        const SizedBox(width: 8),
        _PeriodChip(
          label: 'Este año',
          selected: period == ReportPeriod.thisYear,
          onTap: () => ref.read(reportPeriodProvider.notifier).state =
              ReportPeriod.thisYear,
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ExpenseBreakdownCard extends ConsumerWidget {
  final WidgetRef ref;
  const _ExpenseBreakdownCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportsSummaryProvider);

    return _Card(
      title: 'Gastos por categoría',
      child: summaryAsync.when(
        data: (summary) {
          final byCategory = summary['byCategory'] as List? ?? [];
          final totalExpenses =
              (summary['totalExpenses'] as num?)?.toDouble() ?? 0;

          if (byCategory.isEmpty || totalExpenses == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Sin gastos en este período',
                    style: TextStyle(color: context.colors.textHint)),
              ),
            );
          }

          final sections = byCategory.map<PieChartSectionData>((item) {
            final amount = (item['amount'] as num?)?.toDouble() ?? 0;
            final cat = item['category'] as Map?;
            final colorHex = cat?['color'] as String? ?? '#6B7280';
            final color = _hexColor(colorHex);
            return PieChartSectionData(
              value: amount,
              color: color,
              title: '',
              radius: 38,
            );
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 65,
                    sectionsSpace: 2,
                    startDegreeOffset: -90,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ...byCategory.map((item) {
                final amount = (item['amount'] as num?)?.toDouble() ?? 0;
                final cat = item['category'] as Map?;
                final name = cat?['name'] as String? ?? 'Sin categoría';
                final colorHex = cat?['color'] as String? ?? '#6B7280';
                final color = _hexColor(colorHex);
                final pct = totalExpenses > 0
                    ? (amount / totalExpenses * 100).toStringAsFixed(1)
                    : '0';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(fontSize: 13)),
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                            color: context.colors.textSecondary,
                            fontSize: 12),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        Formatters.currency(amount, symbol: '\$'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }
}

class _MonthlyEvolutionCard extends ConsumerWidget {
  final WidgetRef ref;
  const _MonthlyEvolutionCard({required this.ref});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final evolutionAsync = ref.watch(monthlyEvolutionProvider);

    return _Card(
      title: 'Últimos 6 meses',
      child: evolutionAsync.when(
        data: (months) {
          if (months.isEmpty) return const SizedBox.shrink();

          final maxVal = months.fold<double>(
            1,
            (m, s) => [m, s.income, s.expense].reduce((a, b) => a > b ? a : b),
          );

          final groups = months.asMap().entries.map((e) {
            final i = e.key;
            final m = e.value;
            return BarChartGroupData(
              x: i,
              groupVertically: false,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: m.income,
                  color: AppColors.income,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: m.expense,
                  color: AppColors.expense,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList();

          return Column(
            children: [
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    maxY: maxVal * 1.2,
                    barGroups: groups,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxVal / 3,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: context.colors.border,
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final i = val.toInt();
                            if (i < 0 || i >= months.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                months[i].label,
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.colors.textSecondary),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => context.colors.surface,
                        getTooltipItem: (group, _, rod, rodIndex) {
                          final m = months[group.x];
                          final val = rodIndex == 0 ? m.income : m.expense;
                          final label = rodIndex == 0 ? 'Ingreso' : 'Gasto';
                          return BarTooltipItem(
                            '$label\n${Formatters.currency(val, symbol: '\$')}',
                            TextStyle(fontSize: 11, color: context.colors.textPrimary),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _Legend(color: AppColors.income, label: 'Ingresos'),
                  const SizedBox(width: 20),
                  _Legend(color: AppColors.expense, label: 'Gastos'),
                ],
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('$e', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final Widget child;
  const _Card({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, color: context.colors.textSecondary)),
      ],
    );
  }
}

Color _hexColor(String hex) {
  final h = hex.replaceAll('#', '');
  return Color(int.parse('FF$h', radix: 16));
}
