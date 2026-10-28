/// Declarative Navigator 2.0 navigation built on widgets only.
///
/// The navigation state is a list of pages owned by an [ElixirController]: every change goes through its guards, and
/// an [Elixir] widget renders it.
/// ```dart
/// import 'package:elixir/elixir.dart';
///
/// context.elixir.push(const SettingsPage());
/// context.elixir.change((state) => [...state, const SettingsPage()]);
/// context.elixir.popUntil(Routes.home);
/// ```
library;

export 'src/navigator/controller.dart';
export 'src/navigator/guard.dart';
export 'src/navigator/modal.dart';
export 'src/navigator/navigator.dart';
export 'src/navigator/page.dart';
export 'src/util/extension.dart';
