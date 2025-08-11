import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'login_screen.dart';
import 'main_layout.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration
  await Config.instance.load();

  // Initialize user session from persistent storage
  await UserSession.instance.initialize();

  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  redirect: (context, state) {
    final isLoggedIn = UserSession.instance.isLoggedIn;
    final isLoginRoute = state.matchedLocation == '/login';

    // If user is not logged in and trying to access protected routes, redirect to login
    if (!isLoggedIn && !isLoginRoute) {
      return '/login';
    }

    // If user is logged in and trying to access login page, redirect to projects
    if (isLoggedIn && isLoginRoute) {
      return '/projects';
    }

    // No redirect needed
    return null;
  },
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/projects',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MainLayout(initialIndex: 0),
      ),
    ),
    GoRoute(
      path: '/issues',
      pageBuilder: (context, state) {
        // Check if this is a "My Issues" request (has assignee filter for current user)
        final uri = Uri.parse(state.uri.toString());
        final assignees = uri.queryParameters['assignees'];
        final currentUserId = UserSession.instance.userId?.toString();

        Widget child;
        if (assignees == currentUserId) {
          child = const MainLayout(initialIndex: 2);
        } else {
          child = const MainLayout(initialIndex: 1);
        }

        return NoTransitionPage(child: child);
      },
    ),
    GoRoute(
      path: '/user-management',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MainLayout(initialIndex: 4),
      ),
    ),
    GoRoute(
      path: '/tag-management',
      pageBuilder: (context, state) => const NoTransitionPage(
        child: MainLayout(initialIndex: 5),
      ),
    ),
    // Redirect root to login
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
  ],
);

class NoTransitionPage extends Page {
  final Widget child;

  const NoTransitionPage({required this.child, super.key});

  @override
  Route createRoute(BuildContext context) {
    return PageRouteBuilder(
      settings: this,
      pageBuilder: (context, animation, secondaryAnimation) => child,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: Duration.zero,
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Simple Project',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008080)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
