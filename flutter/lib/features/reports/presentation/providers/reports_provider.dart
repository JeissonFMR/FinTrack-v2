import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/storage/token_storage.dart';

enum ReportPeriod { thisMonth, lastThreeMonths, thisYear }

final reportPeriodProvider =
    StateProvider<ReportPeriod>((ref) => ReportPeriod.thisMonth);

(DateTime, DateTime) _range(ReportPeriod period) {
  final now = DateTime.now();
  return switch (period) {
    ReportPeriod.thisMonth => (
        DateTime(now.year, now.month, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
    ReportPeriod.lastThreeMonths => (
        DateTime(now.year, now.month - 2, 1),
        DateTime(now.year, now.month + 1, 0),
      ),
    ReportPeriod.thisYear => (
        DateTime(now.year, 1, 1),
        DateTime(now.year, 12, 31),
      ),
  };
}

String _fmt(DateTime d) => d.toIso8601String().split('T').first;

final reportsSummaryProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final period = ref.watch(reportPeriodProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return {};

  final (from, to) = _range(period);
  final res = await api.get(
    '/workspaces/$workspaceId/transactions/summary',
    params: {'from': _fmt(from), 'to': _fmt(to)},
  );
  return Map<String, dynamic>.from(res.data as Map);
});

class MonthSummary {
  final String label;
  final double income;
  final double expense;
  const MonthSummary({required this.label, required this.income, required this.expense});
}

final monthlyEvolutionProvider = FutureProvider.autoDispose<List<MonthSummary>>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];

  final now = DateTime.now();
  const monthNames = [
    '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  final futures = List.generate(6, (i) {
    final month = now.month - 5 + i;
    final year = now.year + (month <= 0 ? -1 : 0);
    final m = month <= 0 ? month + 12 : month;
    final from = DateTime(year, m, 1);
    final to = DateTime(year, m + 1, 0);
    return api
        .get('/workspaces/$workspaceId/transactions/summary',
            params: {'from': _fmt(from), 'to': _fmt(to)})
        .then((res) {
      final data = Map<String, dynamic>.from(res.data as Map);
      return MonthSummary(
        label: monthNames[m],
        income: (data['totalIncome'] as num?)?.toDouble() ?? 0,
        expense: (data['totalExpenses'] as num?)?.toDouble() ?? 0,
      );
    });
  });

  return Future.wait(futures);
});
