import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/api/api_client.dart';
import '../../../../core/services/budget_alert_manager.dart';
import '../../../../core/storage/token_storage.dart';

class TransactionFilter {
  final String? type;
  final String? categoryId;
  final String? accountId;
  final DateTime? from;
  final DateTime? to;
  final String? search;

  const TransactionFilter({
    this.type,
    this.categoryId,
    this.accountId,
    this.from,
    this.to,
    this.search,
  });

  TransactionFilter copyWith({
    Object? type = _sentinel,
    Object? categoryId = _sentinel,
    Object? accountId = _sentinel,
    Object? from = _sentinel,
    Object? to = _sentinel,
    Object? search = _sentinel,
  }) =>
      TransactionFilter(
        type: type == _sentinel ? this.type : type as String?,
        categoryId: categoryId == _sentinel ? this.categoryId : categoryId as String?,
        accountId: accountId == _sentinel ? this.accountId : accountId as String?,
        from: from == _sentinel ? this.from : from as DateTime?,
        to: to == _sentinel ? this.to : to as DateTime?,
        search: search == _sentinel ? this.search : search as String?,
      );

  bool get hasFilters =>
      type != null || categoryId != null || accountId != null ||
      from != null || to != null || search != null;
}

const _sentinel = Object();
const _pageSize = 25;

final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

class PaginatedTransactions {
  final List items;
  final int page;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;

  const PaginatedTransactions({
    this.items = const [],
    this.page = 0,
    this.total = 0,
    this.hasMore = true,
    this.isLoadingMore = false,
  });

  PaginatedTransactions copyWith({
    List? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
  }) =>
      PaginatedTransactions(
        items: items ?? this.items,
        page: page ?? this.page,
        total: total ?? this.total,
        hasMore: hasMore ?? this.hasMore,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      );
}

class TransactionsPaginationNotifier
    extends StateNotifier<AsyncValue<PaginatedTransactions>> {
  TransactionsPaginationNotifier(this._ref) : super(const AsyncLoading()) {
    load(reset: true);
  }

  final Ref _ref;
  bool _loading = false;

  Future<void> load({bool reset = false}) async {
    if (_loading && !reset) return;

    final current = state.valueOrNull ?? const PaginatedTransactions();
    if (!reset && !current.hasMore) return;

    _loading = true;
    final nextPage = reset ? 1 : current.page + 1;

    if (!reset && state.hasValue) {
      state = AsyncData(current.copyWith(isLoadingMore: true));
    } else if (reset) {
      state = const AsyncLoading();
    }

    try {
      final api = _ref.read(apiClientProvider);
      final storage = _ref.read(tokenStorageProvider);
      final filter = _ref.read(transactionFilterProvider);
      final workspaceId = await storage.getWorkspaceId();

      if (workspaceId == null) {
        state = const AsyncData(PaginatedTransactions(hasMore: false));
        return;
      }

      final params = <String, String>{
        'limit': '$_pageSize',
        'page': '$nextPage',
        if (filter.type != null) 'type': filter.type!,
        if (filter.categoryId != null) 'categoryId': filter.categoryId!,
        if (filter.from != null) 'from': filter.from!.toIso8601String().split('T').first,
        if (filter.to != null) 'to': filter.to!.toIso8601String().split('T').first,
        if (filter.search != null && filter.search!.isNotEmpty) 'search': filter.search!,
        if (filter.accountId != null) 'accountId': filter.accountId!,
      };

      final res = await api.get('/workspaces/$workspaceId/transactions', params: params);
      final data = Map<String, dynamic>.from(res.data as Map);
      final newItems = data['data'] as List;
      final meta = data['meta'] as Map?;
      final total = (meta?['total'] as num?)?.toInt() ?? 0;

      final allItems = reset ? newItems : [...current.items, ...newItems];

      state = AsyncData(PaginatedTransactions(
        items: allItems,
        page: nextPage,
        total: total,
        hasMore: allItems.length < total,
        isLoadingMore: false,
      ));
    } catch (e, st) {
      if (reset) {
        state = AsyncError(e, st);
      } else {
        state = AsyncData(current.copyWith(isLoadingMore: false));
      }
    } finally {
      _loading = false;
    }
  }

  Future<void> loadMore() => load();
  Future<void> refresh() => load(reset: true);
}

final transactionsPaginationProvider = StateNotifierProvider.autoDispose<
    TransactionsPaginationNotifier, AsyncValue<PaginatedTransactions>>((ref) {
  final notifier = TransactionsPaginationNotifier(ref);
  ref.listen<TransactionFilter>(transactionFilterProvider, (_, _) {
    notifier.load(reset: true);
  });
  return notifier;
});

final categoriesProvider = FutureProvider<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/categories');
  return res.data as List;
});

final accountsListProvider = FutureProvider<List>((ref) async {
  final api = ref.read(apiClientProvider);
  final storage = ref.read(tokenStorageProvider);
  final workspaceId = await storage.getWorkspaceId();
  if (workspaceId == null) return [];
  final res = await api.get('/workspaces/$workspaceId/accounts');
  return res.data as List;
});

class TransactionActionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> delete(String transactionId) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.delete('/workspaces/$workspaceId/transactions/$transactionId');
      ref.read(transactionsPaginationProvider.notifier).refresh();
      ref.read(budgetAlertManagerProvider).checkBudgets();
    });
  }

  Future<void> edit(String transactionId, Map<String, dynamic> data) async {
    final api = ref.read(apiClientProvider);
    final storage = ref.read(tokenStorageProvider);
    final workspaceId = await storage.getWorkspaceId();
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await api.patch('/workspaces/$workspaceId/transactions/$transactionId', data: data);
      ref.read(transactionsPaginationProvider.notifier).refresh();
      ref.read(budgetAlertManagerProvider).checkBudgets();
    });
  }
}

final transactionActionsProvider =
    AsyncNotifierProvider<TransactionActionsNotifier, void>(TransactionActionsNotifier.new);
