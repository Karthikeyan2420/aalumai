import 'package:go_router/go_router.dart';

import '../../features/about/about_screen.dart';
import '../../features/alarms/alarms_screen.dart';
import '../../features/expenses/expenses_screen.dart';
import '../../features/fitness/fitness_screen.dart';
import '../../features/habits/habits_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/dashboard_config_screen.dart';
import '../../features/learning/learning_screen.dart';
import '../../features/meals/meals_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/music/music_screen.dart';
import '../../features/notes/notes_screen.dart';
import '../../features/savings/savings_screen.dart';
import '../../features/schedule/schedule_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/tasks/tasks_screen.dart';
import '../shell/app_shell.dart';

class AppRoutes {
  static const home = '/home';
  static const schedule = '/schedule';
  static const tasks = '/tasks';
  static const fitness = '/fitness';
  static const more = '/more';

  static const expenses = '/expenses';
  static const music = '/music';
  static const alarms = '/alarms';
  static const habits = '/habits';
  static const notes = '/notes';
  static const savings = '/savings';
  static const meals = '/meals';
  static const learning = '/learning';
  static const settings = '/settings';
  static const about = '/about';
  static const dashboardConfig = '/dashboard-config';
}

GoRouter createRouter() {
  return GoRouter(
    initialLocation: AppRoutes.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder:
            (context, state, navigationShell) =>
                AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.schedule,
                builder: (context, state) => const ScheduleScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.tasks,
                builder: (context, state) => const TasksScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.fitness,
                builder: (context, state) => const FitnessScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.more,
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.expenses,
        builder: (context, state) => const ExpensesScreen(),
      ),
      GoRoute(
        path: AppRoutes.music,
        builder: (context, state) => const MusicScreen(),
      ),
      GoRoute(
        path: AppRoutes.alarms,
        builder: (context, state) => const AlarmsScreen(),
      ),
      GoRoute(
        path: AppRoutes.habits,
        builder: (context, state) => const HabitsScreen(),
      ),
      GoRoute(
        path: AppRoutes.notes,
        builder: (context, state) => const NotesScreen(),
      ),
      GoRoute(
        path: AppRoutes.savings,
        builder: (context, state) => const SavingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.meals,
        builder: (context, state) => const MealsScreen(),
      ),
      GoRoute(
        path: AppRoutes.learning,
        builder: (context, state) => const LearningScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.about,
        builder: (context, state) => const AboutScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboardConfig,
        builder: (context, state) => const DashboardConfigScreen(),
      ),
    ],
  );
}
