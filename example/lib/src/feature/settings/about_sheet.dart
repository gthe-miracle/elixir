import 'package:flutter/material.dart';

/// {@template about_sheet}
/// The content of a sheet page: drag it down, tap the barrier or press back to close it.
/// {@endtemplate}
class AboutSheet extends StatelessWidget {
  /// {@macro about_sheet}
  const AboutSheet({super.key});

  @override
  Widget build(BuildContext context) => const Material(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    child: SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [Text('About'), SizedBox(height: 8), Text('A sheet page: an ElixirPage with ElixirSheetPage.')],
          ),
        ),
      ),
    ),
  );
}
