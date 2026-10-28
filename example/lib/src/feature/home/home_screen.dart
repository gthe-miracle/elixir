import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';

import '../../common/routes/routes.dart';
import '../../common/widget/app.dart';

/// {@template home_screen}
/// HomeScreen widget.
/// {@endtemplate}
class HomeScreen extends StatelessWidget {
  /// {@macro home_screen}
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Home'),
      actions: [
        IconButton(
          icon: Icon(Theme.of(context).brightness == Brightness.dark ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => App.toggleThemeOf(context),
        ),
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () => context.elixir.push(SettingsScopePage(data: 'Data from home')),
        ),
      ],
    ),
    // Elixir.stackOf rebuilds this text on every change of the root Elixir.
    body: SafeArea(child: Center(child: Text('Pages: ${context.elixir.state.join(' > ')}'))),
  );
}
