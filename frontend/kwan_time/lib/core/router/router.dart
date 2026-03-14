import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kwan_time/core/navigation/app_navigator.dart';
import 'package:kwan_time/core/navigation/bottom_nav_shell.dart';
import 'package:kwan_time/features/auth/screens/auth_gate.dart';
import 'package:kwan_time/features/auth/screens/login_screen.dart';
import 'package:kwan_time/features/auth/screens/signup_screen.dart';
import 'package:kwan_time/features/spaces/governance/screens/space_settings_screen.dart';
import 'package:kwan_time/features/spaces/invite/screens/join_space_screen.dart';
import 'package:kwan_time/features/spaces/models/space_model.dart';
import 'package:kwan_time/features/spaces/screens/space_detail_screen.dart';
import 'package:kwan_time/features/spaces/screens/spaces_screen.dart';

import '../../features/public_booking/views/booking_view.dart';
import '../../features/spaces/screens/auth_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/slide1_calendar/calendar_screen.dart';
import '../../features/slide2_dashboard/dashboard_screen.dart';
import '../../theme/app_design_system.dart';
import '../theme/kwan_theme.dart';

final goRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    navigatorKey: appNavigatorKey,
    initialLocation: '/',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        name: 'home',
        builder: (_, __) => const BottomNavShell(
          calendarTab: HomeShell(),
          spacesTab: SpacesScreen(),
        ),
      ),
      GoRoute(
        path: '/u/:username/book',
        name: 'public-booking',
        builder: (_, state) {
          final username = state.pathParameters['username'];
          return BookingView(slug: username);
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (BuildContext context, GoRouterState state) =>
            const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        builder: (BuildContext context, GoRouterState state) =>
            const SignupScreen(),
      ),
      GoRoute(
        path: '/spaces/:spaceId/settings',
        builder: (BuildContext context, GoRouterState state) {
          final SpaceModel? space = state.extra as SpaceModel?;
          if (space == null) {
            return const Scaffold(
              body: Center(
                child: Text('Missing space context for settings route.'),
              ),
            );
          }
          return SpaceSettingsScreen(space: space);
        },
      ),
      GoRoute(
        path: '/spaces/:spaceId',
        builder: (BuildContext context, GoRouterState state) {
          final extraSpace = state.extra;
          if (extraSpace is SpaceModel) {
            return _SpaceGate(space: extraSpace);
          }
          final String spaceId = state.pathParameters['spaceId']!;
          return _SpaceRouteLoader(spaceId: spaceId);
        },
      ),
      GoRoute(
        path: '/join/:spaceId',
        builder: (BuildContext context, GoRouterState state) {
          final String spaceId = state.pathParameters['spaceId']!;
          final String role =
              (state.uri.queryParameters['role'] ?? 'member').toLowerCase().trim();
          return JoinSpaceScreen(
            spaceId: spaceId,
            role: role,
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  ),
);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _currentPage == 0,
        onPopInvoked: (didPop) {
          if (didPop) {
            return;
          }
          if (_currentPage > 0) {
            _goToPage(0);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const ClampingScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _SlidePageTransition(
                    index: 0,
                    controller: _pageController,
                    child: CalendarScreen(),
                  ),
                  _SlidePageTransition(
                    index: 1,
                    controller: _pageController,
                    child: DashboardScreen(),
                  ),
                ],
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: KwanColors.textMuted,
                    ),
                    onPressed: () => context.push('/settings'),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildSlideIndicator(),
        ),
      );

  Widget _buildSlideIndicator() => Container(
        color: Colors.transparent,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(2, (index) {
            final active = _currentPage == index;
            return GestureDetector(
              onTap: () => _goToPage(index),
              child: AnimatedContainer(
                duration: AppDesignSystem.fast,
                curve: AppDesignSystem.springStandard,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 24 : 8,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? KwanColors.accent
                      : AppDesignSystem.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
      );

  void _goToPage(int index) {
    _pageController.animateToPage(
      index,
      duration: AppDesignSystem.standard,
      curve: AppDesignSystem.springStandard,
    );
  }
}

class _SlidePageTransition extends StatelessWidget {
  const _SlidePageTransition({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final PageController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final currentPage = controller.hasClients
            ? (controller.page ?? controller.initialPage.toDouble())
            : controller.initialPage.toDouble();
        final delta = (index - currentPage).clamp(-1.0, 1.0);
        final parallaxOffset = delta > 0 ? delta : delta * 0.3;
        final opacity = (1 - (delta.abs() * 0.35)).clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(parallaxOffset * 42, 0),
            child: child,
          ),
        );
      },
      child: this.child,
    );
  }
}

class _SpaceRouteLoader extends StatelessWidget {
  const _SpaceRouteLoader({
    required this.spaceId,
  });

  final String spaceId;

  Future<SpaceModel?> _loadSpace() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('spaces').doc(spaceId).get();
      if (!snapshot.exists) {
        return null;
      }
      return SpaceModel.fromFirestore(snapshot);
    } catch (e) {
      debugPrint('Space route load error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SpaceModel?>(
      future: _loadSpace(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        final space = snapshot.data;
        if (space == null) {
          return const Scaffold(
            body: Center(
              child: Text('Space not found.'),
            ),
          );
        }

        return _SpaceGate(space: space);
      },
    );
  }
}

class _SpaceGate extends StatelessWidget {
  const _SpaceGate({required this.space});

  final SpaceModel space;

  @override
  Widget build(BuildContext context) {
    if (space.storageType == SpaceStorageType.shared) {
      return AuthGate(
        message: 'Sign in to access shared spaces',
        child: SpaceDetailScreen(space: space),
      );
    }
    return SpaceDetailScreen(space: space);
  }
}
