import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class MainShell extends StatelessWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

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
      body: child,
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
