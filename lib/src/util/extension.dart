import 'package:flutter/widgets.dart';

import '../navigator/controller.dart';
import '../navigator/navigator.dart';

/// Shortcuts to the closest [ElixirController].
extension ElixirContextExtension on BuildContext {
  /// The controller of the closest Elixir above this context.
  /// ```dart
  /// context.elixir.push(const SettingsPage());
  /// ```
  ElixirController get elixir => Elixir.of(this);

  /// The controller of the closest Elixir above this context, if any.
  ElixirController? get maybeElixir => Elixir.maybeOf(this);
}
