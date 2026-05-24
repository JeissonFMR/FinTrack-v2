import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/category_icons.dart';
import '../../../../core/utils/formatters.dart';

class _MonthSummary {
  final Map<DateTime, _DayTotals> byDay;
  final Map<DateTime, List<Map<String, dynamic>>> txsByDay;
  const _MonthSummary({required this.byDay, required this.txsByDay});
}

class _DayTotals {
  final double income;
  final double expense;
  const _DayTotals(this.income, this.expense);
  double get net => income - expense;
}

/// Provider que trae todas las transacciones del mes visible y las agrupa por día
final monthCalendarProvider = FutureProvider.autoDispose
    .family<_MonthSummary, DateTime>((ref, focused) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) {
    return const _MonthSummary(byDay: {}, txsByDay: {});
  }

  final from = DateTime(focused.year, focused.month, 1);
  final to = DateTime(focused.year, focused.month + 1, 0);
  final fromStr = from.toIso8601String().split('T').first;
  final toStr = to.toIso8601String().split('T').first;

  final res = await api.get(
    '/workspaces/$workspaceId/transactions',
    params: {'from': fromStr, 'to': toStr, 'limit': '500', 'page': '1'},
  );
  final List items = res.data['data'] as List;

  final Map<DateTime, _DayTotals> byDay = {};
  final Map<DateTime, List<Map<String, dynamic>>> txsByDay = {};

  for (final raw in items) {
    final tx = Map<String, dynamic>.from(raw as Map);
    final date = DateTime.parse(tx['date'] as String);
    final key = DateTime(date.year, date.month, date.day);
    final amount = Formatters.decimal(tx['amount']);
    final type = tx['type'] as String;

    txsByDay.putIfAbsent(key, () => []).add(tx);

    final existing = byDay[key] ?? const _DayTotals(0, 0);
    if (type == 'INCOME') {
      byDay[key] = _DayTotals(existing.income + amount, existing.expense);
    } else if (type == 'EXPENSE') {
      byDay[key] = _DayTotals(existing.income, existing.expense + amount);
    }
  }

  return _MonthSummary(byDay: byDay, txsByDay: txsByDay);
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(monthCalendarProvider(_focusedDay));

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: summaryAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('$e')),
        data: (summary) {
          final selectedKey = _selectedDay == null
              ? null
              : DateTime(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
          final selectedTotals =
              selectedKey != null ? summary.byDay[selectedKey] : null;
          final selectedTxs =
              selectedKey != null ? summary.txsByDay[selectedKey] : null;

          // Total del mes
          double monthIncome = 0;
          double monthExpense = 0;
          for (final t in summary.byDay.values) {
            monthIncome += t.income;
            monthExpense += t.expense;
          }
          final monthNet = monthIncome - monthExpense;

          return Column(
            children: [
              TableCalendar(
                firstDay: DateTime(2020),
                lastDay: DateTime(2035),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                calendarFormat: _calendarFormat,
                startingDayOfWeek: StartingDayOfWeek.monday,
                locale: 'es_CO',
                availableCalendarFormats: const {
                  CalendarFormat.month: 'Mes',
                  CalendarFormat.twoWeeks: '2 sem',
                  CalendarFormat.week: 'Semana',
                },
                onDaySelected: (selected, focused) {
                  setState(() {
                    _selectedDay = selected;
                    _focusedDay = focused;
                  });
                },
                onPageChanged: (focused) {
                  setState(() => _focusedDay = focused);
                },
                onFormatChanged: (fmt) =>
                    setState(() => _calendarFormat = fmt),
                headerStyle: HeaderStyle(
                  formatButtonDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  formatButtonTextStyle:
                      const TextStyle(color: AppColors.primary, fontSize: 12),
                  titleCentered: true,
                  titleTextStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 16),
                ),
                calendarStyle: CalendarStyle(
                  outsideDaysVisible: false,
                  todayDecoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  todayTextStyle: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                  selectedDecoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  selectedTextStyle: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (ctx, day, _) {
                    final key = DateTime(day.year, day.month, day.day);
                    final totals = summary.byDay[key];
                    if (totals == null) return const SizedBox.shrink();
                    final color = totals.net >= 0
                        ? AppColors.income
                        : AppColors.expense;
                    return Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Resumen del mes
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.colors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _MonthStat(
                        label: 'Ingresos',
                        value: monthIncome,
                        color: AppColors.income,
                      ),
                    ),
                    Expanded(
                      child: _MonthStat(
                        label: 'Gastos',
                        value: monthExpense,
                        color: AppColors.expense,
                      ),
                    ),
                    Expanded(
                      child: _MonthStat(
                        label: 'Neto',
                        value: monthNet,
                        color: monthNet >= 0
                            ? AppColors.income
                            : AppColors.expense,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: _DayDetail(
                  day: _selectedDay,
                  totals: selectedTotals,
                  transactions: selectedTxs,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MonthStat extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  const _MonthStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            color: context.colors.textHint,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.currency(value, symbol: '\$'),
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}

class _DayDetail extends ConsumerWidget {
  final DateTime? day;
  final _DayTotals? totals;
  final List<Map<String, dynamic>>? transactions;
  const _DayDetail({
    required this.day,
    required this.totals,
    required this.transactions,
  });

  Color _hex(String hex) =>
      Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (day == null) {
      return Center(
        child: Text('Toca un día para ver el detalle',
            style: TextStyle(color: context.colors.textHint)),
      );
    }

    final txs = transactions ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con fecha y neto
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              Text(
                Formatters.date(day!),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (totals != null && totals!.net != 0)
                Text(
                  '${totals!.net >= 0 ? '+' : ''}${Formatters.currency(totals!.net, symbol: '\$')}',
                  style: TextStyle(
                    color: totals!.net >= 0
                        ? AppColors.income
                        : AppColors.expense,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
            ],
          ),
        ),
        if (totals != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.arrow_downward_rounded,
                    size: 14, color: AppColors.income),
                Text(' ${Formatters.currency(totals!.income, symbol: '\$')}',
                    style: const TextStyle(
                        color: AppColors.income, fontSize: 12)),
                const SizedBox(width: 16),
                Icon(Icons.arrow_upward_rounded,
                    size: 14, color: AppColors.expense),
                Text(' ${Formatters.currency(totals!.expense, symbol: '\$')}',
                    style: const TextStyle(
                        color: AppColors.expense, fontSize: 12)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        Expanded(
          child: txs.isEmpty
              ? Center(
                  child: Text(
                    'Sin movimientos este día',
                    style: TextStyle(color: context.colors.textHint),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: txs.length,
                  separatorBuilder: (_, i) => Divider(
                    height: 0,
                    indent: 64,
                    color: context.colors.divider,
                  ),
                  itemBuilder: (ctx, i) {
                    final tx = txs[i];
                    final isIncome = tx['type'] == 'INCOME';
                    final isTransfer = tx['type'] == 'TRANSFER';
                    final amount = Formatters.decimal(tx['amount']);
                    final category = tx['category'] as Map?;
                    final color = category != null
                        ? _hex(category['color'] as String? ?? '#6B7280')
                        : (isIncome ? AppColors.income : AppColors.expense);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 2),
                      onTap: () => context.push(
                        '/transactions/edit',
                        extra: Map<String, dynamic>.from(tx),
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        child: Icon(
                          isTransfer
                              ? Icons.swap_horiz_rounded
                              : categoryIcon(category?['icon'] as String?),
                          color: color,
                          size: 16,
                        ),
                      ),
                      title: Text(
                        tx['description'] as String? ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.w500, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: category != null
                          ? Text(
                              category['name'] as String,
                              style: TextStyle(
                                  color: context.colors.textSecondary,
                                  fontSize: 11),
                            )
                          : null,
                      trailing: Text(
                        '${isIncome ? '+' : isTransfer ? '' : '-'}${Formatters.currency(amount, symbol: '\$')}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isIncome
                              ? AppColors.income
                              : isTransfer
                                  ? AppColors.primary
                                  : AppColors.expense,
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
