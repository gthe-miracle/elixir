import 'page.dart';

/// The function behind [ElixirGuard.new].
typedef ElixirGuardCallback = ElixirNavigationState Function(ElixirNavigationState from, ElixirNavigationState to);

/// {@template elixir_guard}
/// A rule of the navigation state.
///
/// A guard receives the committed state [from] and the requested state `to`, and returns the state to commit: `to`
/// itself, a redirect, or `from` to cancel the change. It runs on every change, on `controller.revalidate()` and on the
/// initial state, where `from` is empty.
///
/// Guards are pure business rules: they see neither the controller nor a `BuildContext`. Their dependencies are given
/// to the constructor, and the `revalidate` listenable of the controller re-runs them when those change:
/// ```dart
/// final controller = ElixirController(
///   [const HomePage()],
///   guards: [ElixirGuard((from, to) => auth.isSignedIn ? to : [const SignInPage()])],
///   revalidate: auth,
/// );
/// ```
///
/// A guard with state of its own implements this interface. A guard that throws is reported to `FlutterError` and
/// skipped. To keep the user from closing a page, use `PopScope` or `Page.canPop` instead: a page closed with a swipe
/// has already left the navigator when the guards see its removal.
/// {@endtemplate}
abstract interface class ElixirGuard {
  /// A guard from a function.
  ///
  /// {@macro elixir_guard}
  const factory ElixirGuard(ElixirGuardCallback callback) = _CallbackGuard;

  /// Returns the state to commit instead of [to].
  ElixirNavigationState call(ElixirNavigationState from, ElixirNavigationState to);
}

final class _CallbackGuard implements ElixirGuard {
  const _CallbackGuard(this._callback);

  final ElixirGuardCallback _callback;

  @override
  ElixirNavigationState call(ElixirNavigationState from, ElixirNavigationState to) => _callback(from, to);

  @override
  String toString() => 'ElixirGuard()';
}

/// {@template root_guard}
/// Keeps [root] at the bottom of the state, so the state is never empty and going back always ends there.
/// {@endtemplate}
final class RootGuard implements ElixirGuard {
  /// {@macro root_guard}
  const RootGuard(this.root);

  /// The page at the bottom of the state.
  final ElixirPage root;

  @override
  ElixirNavigationState call(ElixirNavigationState from, ElixirNavigationState to) =>
      to.isNotEmpty && to.first.key == root.key ? to : [root, ...to.where((page) => page.key != root.key)];

  @override
  String toString() => 'RootGuard($root)';
}

/// {@template modal_guard}
/// Keeps the pages tagged [ElixirPage.modalTag] above the others, in their order, so a screen pushed while a dialog is
/// open goes under the dialog.
/// {@endtemplate}
final class ModalGuard implements ElixirGuard {
  /// {@macro modal_guard}
  const ModalGuard();

  @override
  ElixirNavigationState call(ElixirNavigationState from, ElixirNavigationState to) {
    bool modal(ElixirPage page) => page.tags.contains(ElixirPage.modalTag);
    final first = to.indexWhere(modal);
    if (first < 0 || to.skip(first).every(modal)) return to;
    return [...to.where((page) => !modal(page)), ...to.where(modal)];
  }

  @override
  String toString() => 'ModalGuard()';
}
