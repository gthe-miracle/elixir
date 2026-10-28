import 'package:flutter/widgets.dart';

/// The navigation state: the pages from the root to the visible one.
typedef ElixirNavigationState = List<ElixirPage>;

/// {@template elixir_page}
/// A screen of the navigation state.
///
/// A page is an immutable value that is also the [Page] given to the [Navigator], so the navigator matches the pages
/// of two states by their [key] and keeps the route, and its state, of a page that stays.
///
/// Subclasses implement [alias] and [createRoute], usually once in a shared sealed base page:
/// ```dart
/// sealed class AppPage extends ElixirPage {
///   const AppPage({required super.child, super.arguments, super.key});
///
///   @override
///   Route<Object?> createRoute(BuildContext context) => ElixirPageRoute(this);
/// }
///
/// final class HomePage extends AppPage {
///   const HomePage() : super(child: const HomeScreen());
///
///   @override
///   ElixirAlias get alias => Routes.home;
/// }
/// ```
///
/// The route must be page-based: it reads the child of its current page, `(settings as ElixirPage).child`, on every
/// build instead of capturing it once. Otherwise a new instance of a page with the same key does not reach the
/// screen. [ElixirPageRoute] and the modal pages are page-based.
///
/// Pages compare by identity. The controller identifies them by [key].
/// {@endtemplate}
@immutable
abstract base class ElixirPage extends Page<Object?> {
  /// {@macro elixir_page}
  const ElixirPage({required this.child, Map<String, Object?>? super.arguments, super.key, super.restorationId});

  /// The tag of the pages that cover the screen with a barrier: dialogs and sheets.
  ///
  /// `controller.removeTag(ElixirPage.modalTag)` closes all of them, and [ModalGuard] keeps them above the screens.
  static const String modalTag = 'modal';

  /// The content of the page.
  final Widget child;

  /// The alias of the page, usually an enum value. The [name] comes from it.
  ElixirAlias get alias;

  /// Marks used to address groups of pages, e.g. `controller.removeTag('checkout')`.
  Set<String> get tags => const <String>{};

  @override
  String get name => alias.alias;

  @override
  Map<String, Object?> get arguments => switch (super.arguments) {
    final Map<String, Object?> arguments => arguments,
    _ => const <String, Object?>{},
  };

  /// The identity of the page in the state; keys must be unique within one state.
  ///
  /// Defaults to the key given to the constructor, otherwise to `name`, or `name?a=1&b` with [arguments] (`b` has a
  /// `null` value). `%`, `&`, `=` and `?` are escaped, so a separator inside a value never produces another key.
  ///
  /// A page that keeps its parameters in fields must override it, otherwise all its instances are one screen:
  /// ```dart
  /// @override
  /// LocalKey get key => ValueKey<String>('product/$id');
  /// ```
  @override
  LocalKey get key {
    if (super.key case final LocalKey key) return key;
    final name = _escape(this.name);
    if (arguments.isEmpty) return ValueKey<String>(name);
    final query = arguments.entries
        .map(
          (entry) => switch (entry.value) {
            null => _escape(entry.key),
            final Object value => '${_escape(entry.key)}=${_escape('$value')}',
          },
        )
        .join('&');
    return ValueKey<String>('$name?$query');
  }

  static String _escape(String value) =>
      value.replaceAll('%', '%25').replaceAll('&', '%26').replaceAll('=', '%3D').replaceAll('?', '%3F');

  @override
  String toString() => switch (key) {
    ValueKey<String>(:final value) => value,
    final key => '$name$key',
  };
}

/// {@template elixir_page_route}
/// A page-based route for an [ElixirPage], built on widgets only.
///
/// Every build reads the child of the current page, so replacing a page with a new instance under the same key
/// updates the screen and keeps the state of the route.
/// ```dart
/// @override
/// Route<Object?> createRoute(BuildContext context) => ElixirPageRoute(this);
/// ```
///
/// For the transitions of Material or Cupertino, use their page-based mixins in the app:
/// ```dart
/// final class AppPageRoute extends PageRoute<Object?> with MaterialRouteTransitionMixin<Object?> {
///   AppPageRoute(AppPage page) : super(settings: page);
///
///   @override
///   Widget buildContent(BuildContext context) => (settings as AppPage).child;
///
///   @override
///   bool get maintainState => true;
/// }
/// ```
/// {@endtemplate}
final class ElixirPageRoute extends PageRoute<Object?> {
  /// {@macro elixir_page_route}
  ElixirPageRoute(
    ElixirPage page, {
    this.transitionDuration = const Duration(milliseconds: 300),
    this.transitionsBuilder = _fade,
    super.fullscreenDialog,
  }) : super(settings: page);

  /// Builds the transition around the page, a fade by default.
  final RouteTransitionsBuilder transitionsBuilder;

  @override
  final Duration transitionDuration;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      (settings as ElixirPage).child;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => transitionsBuilder(context, animation, secondaryAnimation, child);

  static Widget _fade(BuildContext context, Animation<double> animation, Animation<double> _, Widget child) =>
      FadeTransition(opacity: animation, child: child);
}

/// The alias of a page, usually an enum value. Aliases must be unique, since the page name and key come from them.
///
/// ```dart
/// enum Routes implements ElixirAlias {
///   home('home'),
///   settings('settings');
///
///   const Routes(this.alias);
///
///   @override
///   final String alias;
/// }
/// ```
abstract interface class ElixirAlias {
  /// The alias of the page.
  String get alias;
}
