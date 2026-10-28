import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';

import '../../common/routes/routes.dart';
import '../../common/widget/app.dart';

/// {@template settings_screen}
/// SettingsScreen widget.
/// {@endtemplate}
class SettingsScreen extends StatefulWidget {
  /// {@macro settings_screen}
  const SettingsScreen({required this.data, super.key});

  final String data;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _result;

  Future<void> _openDialog() async {
    final result = await context.elixir.pushForResult<bool>(const SettingsDialogPage());
    if (mounted) setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.cyan,
    appBar: AppBar(
      // The settings Elixir has a single page: leave it through the root one.
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => App.controllerOf(context).popUntil(AppRoutes.home),
      ),
      title: const Text('Settings'),
    ),
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('data: ${widget.data}'),
            Text('Dialog result: $_result'),
            TextButton(onPressed: _openDialog, child: const Text('Open dialog')),
            TextButton(onPressed: () => context.elixir.push(const AboutSheetPage()), child: const Text('Open sheet')),
          ],
        ),
      ),
    ),
  );
}
