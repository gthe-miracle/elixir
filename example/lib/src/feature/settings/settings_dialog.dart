import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';

import '../../common/widget/app.dart';

/// {@template settings_dialog}
/// The content of a dialog page; it pops `true` or `false` to its `pushForResult`.
/// {@endtemplate}
class SettingsDialog extends StatelessWidget {
  /// {@macro settings_dialog}
  const SettingsDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Settings'),
    content: Text(
      'App pages: ${App.controllerOf(context).state.length}\n'
      'Settings pages: ${context.elixir.state.length}',
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
      TextButton(onPressed: () => context.elixir.pop(true), child: const Text('OK')),
    ],
  );
}
