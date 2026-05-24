import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../services/biometric_service.dart';
import '../../features/auth/presentation/screens/biometric_lock_screen.dart';
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
import '../../features/assistant/presentation/screens/assistant_screen.dart';
import '../../features/calendar/presentation/screens/calendar_screen.dart';
import '../../features/categories/presentation/screens/categories_screen.dart';
import '../../features/recurring/presentation/screens/recurring_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final unlocked = ref.watch(sessionUnlockedProvider);

  return GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) async {
      final isLoggedIn = authState.valueOrNull ?? false;
      final loc = state.matchedLocation;
      final isAuthRoute =
          loc.startsWith('/login') || loc.startsWith('/register');
      final isLockRoute = loc.startsWith('/lock');

      if (!isLoggedIn && !isAuthRoute) return '/login';
      if (isLoggedIn && isAuthRoute) {
        // Si tiene biométrico activo, pasa por la pantalla de lock antes
        final useBio = await BiometricService.instance.isEnabled();
        if (useBio && !unlocked) return '/lock';
        return '/dashboard';
      }
      if (isLoggedIn && !isLockRoute && !unlocked) {
        final useBio = await BiometricService.instance.isEnabled();
        if (useBio) return '/lock';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (ctx, st) => const LoginScreen()),
      GoRoute(path: '/register', builder: (ctx, st) => const RegisterScreen()),
      GoRoute(path: '/lock', builder: (ctx, st) => const BiometricLockScreen()),
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
      GoRoute(path: '/recurring', builder: (ctx, st) => const RecurringScreen()),
      GoRoute(path: '/reports', builder: (ctx, st) => const ReportsScreen()),
      GoRoute(path: '/assistant', builder: (ctx, st) => const AssistantScreen()),
      GoRoute(path: '/calendar', builder: (ctx, st) => const CalendarScreen()),
    ],
  );
});
