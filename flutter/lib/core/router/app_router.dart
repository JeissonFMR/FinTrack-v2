import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/dashboard/presentation/screens/main_shell.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/add_transaction_screen.dart';
import '../../features/accounts/presentation/screens/accounts_screen.dart';
import '../../features/accounts/presentation/screens/add_account_screen.dart';
import '../../features/budgets/presentation/screens/budgets_screen.dart';
import '../../features/goals/presentation/screens/goals_screen.dart';
import '../../features/debts/presentation/screens/debts_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull ?? false;
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, st) => const RegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (ctx, st) => const DashboardScreen()),
          GoRoute(path: '/transactions', builder: (ctx, st) => const TransactionsScreen()),
          GoRoute(path: '/accounts', builder: (ctx, st) => const AccountsScreen()),
          GoRoute(path: '/budgets', builder: (ctx, st) => const BudgetsScreen()),
          GoRoute(path: '/goals', builder: (ctx, st) => const GoalsScreen()),
          GoRoute(path: '/debts', builder: (ctx, st) => const DebtsScreen()),
          GoRoute(path: '/settings', builder: (ctx, st) => const SettingsScreen()),
        ],
      ),
      GoRoute(path: '/transactions/add', builder: (ctx, st) => const AddTransactionScreen()),
      GoRoute(
        path: '/transactions/edit',
        builder: (ctx, st) => AddTransactionScreen(
          transaction: st.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(path: '/accounts/add', builder: (ctx, st) => const AddAccountScreen()),
      GoRoute(
        path: '/accounts/edit',
        builder: (ctx, st) => AddAccountScreen(
          account: st.extra as Map<String, dynamic>?,
        ),
      ),
      GoRoute(path: '/categories', builder: (ctx, st) => const CategoriesScreen()),
      GoRoute(path: '/reports', builder: (ctx, st) => const ReportsScreen()),
    ],
  );
});
