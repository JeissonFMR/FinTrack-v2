import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/presentation/providers/dashboard_provider.dart';
import '../providers/transactions_provider.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  final _scrollCtrl = ScrollController();
  final _searchCtrl = TextEditingController();
  bool _searchActive = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 250) {
      ref.read(transactionsPaginationProvider.notifier).loadMore();
    }
  }

  void _toggleSearch() {
    setState(() => _searchActive = !_searchActive);
    if (!_searchActive) {
      _searchCtrl.clear();
      ref.read(transactionFilterProvider.notifier).state =
          ref.read(transactionFilterProvider).copyWith(search: null);
    }
  }

  void _onSearchChanged(String value) {
    ref.read(transactionFilterProvider.notifier).state =
        ref.read(transactionFilterProvider).copyWith(
          search: value.isEmpty ? null : value,
        );
  }

  @override
  Widget build(BuildContext context) {
    final paginatedAsync = ref.watch(transactionsPaginationProvider);
    final filter = ref.watch(transactionFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: _searchActive
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar movimientos...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: context.colors.textHint),
                ),
                style: const TextStyle(fontSize: 16),
              )
            : const Text('Movimientos'),
        actions: [
          if (_searchActive)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _toggleSearch,
            )
          else ...[
            if (filter.hasFilters)
              TextButton(
                onPressed: () => ref
                    .read(transactionFilterProvider.notifier)
                    .state = const TransactionFilter(),
                child: const Text('Limpiar'),
              ),
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: _toggleSearch,
            ),
            IconButton(
              icon: Badge(
                isLabelVisible: filter.hasFilters,
                backgroundColor: AppColors.primary,
                child: const Icon(Icons.tune_rounded),
              ),
              onPressed: () => _showFilterSheet(context, ref),
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => context.push('/transactions/add'),
            ),
          ],
        ],
      ),
      body: paginatedAsync.when(
        data: (paginated) {
          final txs = paginated.items;
          final total = paginated.total;

          if (txs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 48, color: context.colors.textHint),
                  const SizedBox(height: 12),
                  Text('Sin movimientos',
                      style: TextStyle(color: context.colors.textSecondary)),
                  if (filter.hasFilters) ...[
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => ref
                          .read(transactionFilterProvider.notifier)
                          .state = const TransactionFilter(),
                      child: const Text('Quitar filtros'),
                    ),
                  ],
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(transactionsPaginationProvider.notifier).refresh(),
            color: AppColors.primary,
            child: Column(
              children: [
                if (filter.hasFilters)
                  _FilterChips(filter: filter, ref: ref),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$total movimiento${total != 1 ? 's' : ''}',
                      style: TextStyle(
                          color: context.colors.textSecondary, fontSize: 13),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollCtrl,
                    itemCount: txs.length + (paginated.isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, i) =>
                        i < txs.length - 1
                            ? const Divider(height: 0, indent: 72)
                            : const SizedBox.shrink(),
                    itemBuilder: (ctx, i) {
                      if (i == txs.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          ),
                        );
                      }
                      return _TxTile(tx: txs[i], ref: ref);
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, st) => Center(
          child: Text('$err', style: const TextStyle(color: AppColors.expense)),
        ),
      ),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilterSheet(ref: ref),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final TransactionFilter filter;
  final WidgetRef ref;
  const _FilterChips({required this.filter, required this.ref});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          if (filter.type != null)
            _Chip(
              label: _typeLabel(filter.type!),
              onRemove: () => ref.read(transactionFilterProvider.notifier).state =
                  filter.copyWith(type: null),
            ),
          if (filter.from != null || filter.to != null)
            _Chip(
              label: [
                if (filter.from != null) Formatters.shortDate(filter.from!),
                if (filter.to != null) Formatters.shortDate(filter.to!),
              ].join(' – '),
              onRemove: () => ref.read(transactionFilterProvider.notifier).state =
                  filter.copyWith(from: null, to: null),
            ),
          if (filter.search != null)
            _Chip(
              label: '"${filter.search}"',
              onRemove: () => ref.read(transactionFilterProvider.notifier).state =
                  filter.copyWith(search: null),
            ),
          if (filter.categoryId != null)
            _Chip(
              label: 'Categoría activa',
              onRemove: () => ref.read(transactionFilterProvider.notifier).state =
                  filter.copyWith(categoryId: null),
            ),
          if (filter.accountId != null)
            _Chip(
              label: 'Cuenta activa',
              onRemove: () => ref.read(transactionFilterProvider.notifier).state =
                  filter.copyWith(accountId: null),
            ),
        ],
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'INCOME' => 'Ingresos',
        'EXPENSE' => 'Gastos',
        'TRANSFER' => 'Transferencias',
        _ => type,
      };
}

class _Chip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _Chip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colors.primaryLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w500)),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final WidgetRef ref;
  const _FilterSheet({required this.ref});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TransactionFilter _local;

  @override
  void initState() {
    super.initState();
    _local = widget.ref.read(transactionFilterProvider);
  }

  void _apply() {
    widget.ref.read(transactionFilterProvider.notifier).state = _local;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = widget.ref.watch(categoriesProvider);
    final accountsAsync = widget.ref.watch(accountsListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Filtros',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                TextButton(
                  onPressed: () {
                    setState(() => _local = const TransactionFilter());
                  },
                  child: const Text('Limpiar todo'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              children: [
                // Tipo
                const Text('Tipo',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterOption(label: 'Todos', selected: _local.type == null,
                        onTap: () => setState(() => _local = _local.copyWith(type: null))),
                    _FilterOption(label: 'Ingresos', selected: _local.type == 'INCOME',
                        onTap: () => setState(() => _local = _local.copyWith(type: 'INCOME'))),
                    _FilterOption(label: 'Gastos', selected: _local.type == 'EXPENSE',
                        onTap: () => setState(() => _local = _local.copyWith(type: 'EXPENSE'))),
                    _FilterOption(label: 'Transferencias', selected: _local.type == 'TRANSFER',
                        onTap: () => setState(() => _local = _local.copyWith(type: 'TRANSFER'))),
                  ],
                ),
                const SizedBox(height: 20),

                // Categoría
                const Text('Categoría',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                categoriesAsync.when(
                  data: (cats) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'Todas',
                        selected: _local.categoryId == null,
                        onTap: () => setState(() => _local = _local.copyWith(categoryId: null)),
                      ),
                      ...cats.map((c) => _FilterOption(
                            label: c['name'] as String,
                            selected: _local.categoryId == c['id'],
                            onTap: () => setState(
                                () => _local = _local.copyWith(categoryId: c['id'] as String)),
                          )),
                    ],
                  ),
                  loading: () => const SizedBox(height: 32,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Cuenta
                const Text('Cuenta',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                accountsAsync.when(
                  data: (accounts) => Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FilterOption(
                        label: 'Todas',
                        selected: _local.accountId == null,
                        onTap: () => setState(() => _local = _local.copyWith(accountId: null)),
                      ),
                      ...accounts.map((a) => _FilterOption(
                            label: a['name'] as String,
                            selected: _local.accountId == a['id'],
                            onTap: () => setState(
                                () => _local = _local.copyWith(accountId: a['id'] as String)),
                          )),
                    ],
                  ),
                  loading: () => const SizedBox(height: 32,
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 20),

                // Período
                const Text('Período',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: [
                    _FilterOption(
                      label: 'Este mes',
                      selected: _isThisMonth(),
                      onTap: () {
                        final now = DateTime.now();
                        setState(() => _local = _local.copyWith(
                              from: DateTime(now.year, now.month, 1),
                              to: DateTime(now.year, now.month + 1, 0),
                            ));
                      },
                    ),
                    _FilterOption(
                      label: 'Mes pasado',
                      selected: _isLastMonth(),
                      onTap: () {
                        final now = DateTime.now();
                        setState(() => _local = _local.copyWith(
                              from: DateTime(now.year, now.month - 1, 1),
                              to: DateTime(now.year, now.month, 0),
                            ));
                      },
                    ),
                    _FilterOption(
                      label: 'Este año',
                      selected: _isThisYear(),
                      onTap: () {
                        final now = DateTime.now();
                        setState(() => _local = _local.copyWith(
                              from: DateTime(now.year, 1, 1),
                              to: DateTime(now.year, 12, 31),
                            ));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(onPressed: _apply, child: const Text('Aplicar filtros')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isThisMonth() {
    final now = DateTime.now();
    return _local.from?.month == now.month &&
        _local.from?.year == now.year &&
        _local.to?.month == now.month;
  }

  bool _isLastMonth() {
    final now = DateTime.now();
    final last = now.month == 1 ? 12 : now.month - 1;
    return _local.from?.month == last && _local.to?.month == last;
  }

  bool _isThisYear() {
    final now = DateTime.now();
    return _local.from?.year == now.year &&
        _local.from?.month == 1 &&
        _local.to?.month == 12;
  }
}

class _FilterOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterOption(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? context.colors.primaryLight : context.colors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TxTile extends StatelessWidget {
  final dynamic tx;
  final WidgetRef ref;
  const _TxTile({required this.tx, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx['type'] == 'INCOME';
    final isTransfer = tx['type'] == 'TRANSFER';
    final amount = Formatters.decimal(tx['amount']);
    final category = tx['category'];
    final date = DateTime.parse(tx['date']);
    final txId = tx['id'] as String;

    final iconColor = isTransfer ? AppColors.primary : isIncome ? AppColors.income : AppColors.expense;
    final bgColor = isTransfer ? context.colors.primaryLight : isIncome ? AppColors.incomeLight : AppColors.expenseLight;
    final icon = isTransfer ? Icons.swap_horiz_rounded : isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;

    return Dismissible(
      key: ValueKey(txId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.expense,
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar movimiento'),
            content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.expense),
                child: const Text('Eliminar'),
              ),
            ],
          ),
        ) ?? false;
      },
      onDismissed: (_) async {
        await ref.read(transactionActionsProvider.notifier).delete(txId);
        ref.invalidate(dashboardSummaryProvider);
        ref.invalidate(recentTransactionsProvider);
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        onTap: () => context.push('/transactions/edit',
            extra: Map<String, dynamic>.from(tx as Map)),
        onLongPress: () => context.push('/transactions/edit',
            extra: Map<String, dynamic>.from(tx as Map)),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(tx['description'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        subtitle: Text(
          '${category != null ? '${category['name']} · ' : ''}${Formatters.date(date)}',
          style: TextStyle(color: context.colors.textSecondary, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${isIncome ? '+' : isTransfer ? '' : '-'}${Formatters.currency(amount, symbol: '\$')}',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isIncome ? AppColors.income : isTransfer ? AppColors.primary : AppColors.expense,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: context.colors.textHint),
          ],
        ),
      ),
    );
  }
}
