import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/background_capture_service.dart';
import '../../../../core/services/bank_notification_listener.dart'
    show ParsedBankTransaction;
import '../../../transactions/presentation/widgets/detected_tx_sheet.dart';

class MainShell extends ConsumerStatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  StreamSubscription<Map<String, dynamic>?>? _bgDetectedSub;
  bool _showingSheet = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Suscribirse al stream que emite el background service en vivo
      _bgDetectedSub =
          BackgroundCaptureService.detections.listen(_onDetectedBackground);

      // Procesar detecciones que el background dejó guardadas cuando la
      // app estaba cerrada
      await _processPending();
    });
  }

  Future<void> _processPending() async {
    final pending = await readPendingDetections();
    if (pending.isEmpty || !mounted) return;
    await clearPendingDetections();
    for (final raw in pending) {
      if (!mounted) return;
      await _showSheet(ParsedBankTransaction.fromJson(raw));
    }
  }

  void _onDetectedBackground(Map<String, dynamic>? data) {
    if (!mounted || data == null) return;
    _showSheet(ParsedBankTransaction.fromJson(data));
  }

  Future<void> _showSheet(ParsedBankTransaction parsed) async {
    if (_showingSheet) return; // evita sheets encimados
    _showingSheet = true;
    try {
      await DetectedTxSheet.show(context, parsed);
    } finally {
      _showingSheet = false;
    }
  }

  @override
  void dispose() {
    _bgDetectedSub?.cancel();
    super.dispose();
  }

  static const _tabs = [
    ('/dashboard',    Icons.home_outlined,                    Icons.home_rounded,                    'Inicio'),
    ('/transactions', Icons.receipt_long_outlined,            Icons.receipt_long_rounded,            'Movimientos'),
    ('/accounts',     Icons.account_balance_wallet_outlined,  Icons.account_balance_wallet_rounded,  'Cuentas'),
    ('/budgets',      Icons.donut_large_outlined,             Icons.donut_large_rounded,             'Presupuesto'),
    ('/goals',        Icons.flag_outlined,                    Icons.flag_rounded,                    'Metas'),
    ('/debts',        Icons.account_balance_outlined,         Icons.account_balance_rounded,         'Deudas'),
  ];

  int _indexFor(BuildContext context) {
    final loc = GoRouterState.of(context).matchedLocation;
    final i = _tabs.indexWhere((t) => loc.startsWith(t.$1));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexFor(context);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.colors.border)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) => context.go(_tabs[i].$1),
          items: _tabs
              .map((t) => BottomNavigationBarItem(
                    icon: Icon(t.$2),
                    activeIcon: Icon(t.$3),
                    label: t.$4,
                  ))
              .toList(),
        ),
      ),
    );
  }
}
