import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'login_screen.dart';
import 'main_layout.dart';
import 'config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration
  await Config.instance.load();

  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/projects',
      builder: (context, state) => const MainLayout(initialIndex: 0),
    ),
    GoRoute(
      path: '/issues',
      builder: (context, state) {
        // Check if this is a "My Issues" request (has assignee filter for current user)
        final uri = Uri.parse(state.uri.toString());
        final assignees = uri.queryParameters['assignees'];
        final currentUserId = UserSession.instance.userId?.toString();

        if (assignees == currentUserId) {
          return const MainLayout(initialIndex: 2);
        } else {
          return const MainLayout(initialIndex: 1);
        }
      },
    ),
    // Redirect root to login
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Simple Project',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF667eea)),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
