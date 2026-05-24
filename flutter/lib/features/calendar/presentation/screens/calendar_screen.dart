import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/token_storage.dart';
import '../../../../core/utils/formatters.dart';

class _MonthSummary {
  final Map<DateTime, _DayTotals> byDay;
  const _MonthSummary(this.byDay);
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
  if (workspaceId == null) return const _MonthSummary({});

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
  for (final raw in items) {
    final tx = raw as Map<String, dynamic>;
    final date = DateTime.parse(tx['date'] as String);
    final key = DateTime(date.year, date.month, date.day);
    final amount = Formatters.decimal(tx['amount']);
    final type = tx['type'] as String;

    final existing = byDay[key] ?? const _DayTotals(0, 0);
    if (type == 'INCOME') {
      byDay[key] = _DayTotals(existing.income + amount, existing.expense);
    } else if (type == 'EXPENSE') {
      byDay[key] = _DayTotals(existing.income, existing.expense + amount);
    }
  }

  return _MonthSummary(byDay);
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
  const _DayDetail({required this.day, required this.totals});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (day == null) {
      return Center(
        child: Text('Toca un día para ver el detalle',
            style: TextStyle(color: context.colors.textHint)),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
          const SizedBox(height: 8),
          if (totals == null)
            Text('Sin movimientos este día',
                style: TextStyle(color: context.colors.textHint))
          else
            Row(
              children: [
                Icon(Icons.arrow_downward_rounded,
                    size: 16, color: AppColors.income),
                Text(' ${Formatters.currency(totals!.income, symbol: '\$')}',
                    style: const TextStyle(
                        color: AppColors.income, fontSize: 13)),
                const SizedBox(width: 16),
                Icon(Icons.arrow_upward_rounded,
                    size: 16, color: AppColors.expense),
                Text(' ${Formatters.currency(totals!.expense, symbol: '\$')}',
                    style: const TextStyle(
                        color: AppColors.expense, fontSize: 13)),
              ],
            ),
          const SizedBox(height: 12),
          Center(
            child: TextButton.icon(
              onPressed: () {
                final dayStr =
                    day!.toIso8601String().split('T').first;
                context.push('/transactions?date=$dayStr');
              },
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('Ver movimientos del día'),
            ),
          ),
        ],
      ),
    );
  }
}
