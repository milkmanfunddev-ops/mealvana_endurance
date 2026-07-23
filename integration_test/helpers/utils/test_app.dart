import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Creates a test app wrapper for integration testing
/// Provides a MaterialApp with ProviderScope and optional routing
Widget createTestApp({
  List overrides = const [],
  String? initialRoute,
  Widget? child,
  GoRouter? router,
}) {
  // If a router is provided, use MaterialApp.router
  if (router != null) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp.router(
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }

  // If a child widget is provided, wrap it in MaterialApp
  if (child != null) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(home: child, debugShowCheckedModeBanner: false),
    );
  }

  // Default: MaterialApp with optional initial route
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      initialRoute: initialRoute ?? '/',
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: Text('Test App'))),
    ),
  );
}

/// Creates a simple MaterialApp wrapper for widget testing
/// Useful when you just need Material context without routing
Widget createSimpleTestApp({
  required Widget child,
  List overrides = const [],
  ThemeData? theme,
}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: child,
      theme: theme,
      debugShowCheckedModeBanner: false,
    ),
  );
}

/// Creates a test ProviderContainer for unit testing providers
/// without widget context
ProviderContainer createTestContainer({List overrides = const []}) {
  return ProviderContainer(overrides: overrides.cast());
}
