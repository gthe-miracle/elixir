import 'package:elixir/elixir.dart';
import 'package:flutter/cupertino.dart';

import '../../feature/home/home_screen.dart';
import '../../feature/settings/about_sheet.dart';
import '../../feature/settings/settings_dialog.dart';
import '../../feature/settings/settings_scope.dart';
import '../../feature/settings/settings_screen.dart';
import 'custom_route_transitions.dart';

/// The pages of the root Elixir; `app` names the root Elixir itself.
enum AppRoutes implements ElixirAlias {
  app('app'),
  home('home'),
  settings('settings_scope');

  const AppRoutes(this.alias);

  @override
  final String alias;
}

/// The pages of the settings Elixir, nested in [SettingsScopePage].
enum Settings implements ElixirAlias {
  settings('settings'),
  dialog('settings_dialog'),
  about('about'),
  detail('settings_detail');

  const Settings(this.alias);

  @override
  final String alias;
}

/// Reads the child of its current page on every build, so a new page under the same key updates the screen.
final class AppPageRoute extends PageRoute<Object?> with CupertinoRouteTransitionMixin<Object?> {
  AppPageRoute(AppPage page) : super(settings: page);

  @override
  Widget buildContent(BuildContext context) => (settings as AppPage).child;

  /// Shown as the previous-page title by a `CupertinoNavigationBar`; none here.
  @override
  String? get title => null;

  @override
  bool get maintainState => true;
}

/// The base of every page: Cupertino transitions with the swipe-back gesture on every platform, page-based.
@immutable
sealed class AppPage extends ElixirPage {
  const AppPage({required super.child, super.arguments, super.key});

  @override
  Route<Object?> createRoute(BuildContext context) => AppPageRoute(this);
}

final class HomePage extends AppPage {
  const HomePage() : super(child: const HomeScreen());

  @override
  ElixirAlias get alias => AppRoutes.home;
}

final class SettingsScopePage extends AppPage {
  SettingsScopePage({required this.data})
    : super(
        child: SettingsScope(data: data),
        arguments: {'data': data},
      );

  final String data;

  @override
  ElixirAlias get alias => AppRoutes.settings;
}

final class SettingsPage extends AppPage {
  SettingsPage({required this.data})
    : super(
        child: SettingsScreen(data: data),
        arguments: {'data': data},
      );

  final String data;

  @override
  Route<Object?> createRoute(BuildContext context) => CustomMaterialRoute(page: this);

  @override
  ElixirAlias get alias => Settings.settings;
}

final class SettingsDetailPage extends AppPage {
  const SettingsDetailPage() : super(child: const SettingsScreenDetail());

  @override
  ElixirAlias get alias => Settings.detail;
}

/// Opened with `pushForResult<bool>`: the dialog pops `true` or `false`.
final class SettingsDialogPage extends AppPage with ElixirDialogPage {
  const SettingsDialogPage() : super(child: const SettingsDialog());

  @override
  ElixirAlias get alias => Settings.dialog;
}

final class AboutSheetPage extends AppPage with ElixirSheetPage {
  const AboutSheetPage() : super(child: const AboutSheet());

  @override
  ElixirAlias get alias => Settings.about;
}
