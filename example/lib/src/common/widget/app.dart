import 'dart:developer';

import 'package:elixir/elixir.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../routes/routes.dart';

/// {@template app}
/// App widget.
/// {@endtemplate}
class App extends StatefulWidget {
  /// {@macro app}
  const App({super.key});

  /// The controller of the root Elixir, e.g. to leave a nested one.
  static ElixirController controllerOf(BuildContext context) =>
      context.findAncestorStateOfType<_AppState>()!._controller;

  /// Switches between light and dark theme, to compare page transitions in both.
  static void toggleThemeOf(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    context.findAncestorStateOfType<_AppState>()?.setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final ElixirController _controller = ElixirController(
    [const HomePage()],
    guards: const [RootGuard(HomePage()), ModalGuard()],
    name: AppRoutes.app,
  );
  ThemeMode _themeMode = ThemeMode.system;

  void setThemeMode(ThemeMode mode) => setState(() => _themeMode = mode);

  /// Every change of every Elixir, nested ones included, bubbles up to here.
  bool _log(ElixirNotification notification) {
    log('${notification.controller.name?.alias}: ${notification.next.join(' > ')}', name: 'elixir');
    return false;
  }

  static const PageTransitionsTheme _transitions = PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    },
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Declarative Navigation',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: Brightness.light, pageTransitionsTheme: _transitions),
    darkTheme: ThemeData(brightness: Brightness.dark, pageTransitionsTheme: _transitions),
    themeMode: _themeMode,
    builder: (context, _) => NotificationListener<ElixirNotification>(
      onNotification: _log,
      child: Elixir(controller: _controller),
    ),
  );
}
