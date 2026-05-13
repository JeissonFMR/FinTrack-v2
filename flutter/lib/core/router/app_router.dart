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
import '../../features/budgets/presentation/screens/budgets_screen.dart';

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
        ],
      ),
      GoRoute(
        path: '/transactions/add',
        builder: (ctx, st) => const AddTransactionScreen(),
      ),
    ],
  );
});
