import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'guard.dart';
import 'page.dart';

/// A change of the navigation state: it receives a mutable copy of the state and returns the requested one.
///
/// ```dart
/// controller.change((state) => [...state, const SettingsPage()]);
/// controller.change((state) => state..removeLast());
/// ```
typedef ElixirChange = ElixirNavigationState Function(ElixirNavigationState state);

/// A queued change, with the results of the pages it removes.
typedef _Command = (ElixirNavigationState, Map<LocalKey, Object?>) Function(ElixirNavigationState state);

/// {@template elixir_controller}
/// The owner of the navigation state.
///
/// Every change goes through one pipeline: the change, then dedupe by key (the last page wins), then the [guards],
/// then dedupe again. A result that is empty or equal to the current state is rejected; otherwise it is committed and
/// the listeners are notified once.
///
/// A change requested while another one is committed, e.g. from a listener, is queued and applied after it, in order.
///
/// The controller knows no widgets, so it can be created, changed and tested without any. Render it with `Elixir`.
/// ```dart
/// final controller = ElixirController(
///   [const HomePage()],
///   guards: [const RootGuard(HomePage())],
///   name: Routes.app,
/// );
/// ```
/// {@endtemplate}
final class ElixirController extends ChangeNotifier implements ValueListenable<ElixirNavigationState> {
  /// {@macro elixir_controller}
  ///
  /// The [initial] state is validated by the [guards] right away, so the first frame is already consistent. Throws
  /// an [ArgumentError] when nothing is left of it. [revalidate] re-runs the guards whenever it notifies.
  ElixirController(
    ElixirNavigationState initial, {
    List<ElixirGuard> guards = const <ElixirGuard>[],
    Listenable? revalidate,
    this.name,
  }) : guards = List<ElixirGuard>.unmodifiable(guards),
       _initial = List<ElixirPage>.unmodifiable(initial),
       _revalidate = revalidate {
    final state = _validate(const <ElixirPage>[], List<ElixirPage>.of(initial));
    if (state.isEmpty) throw ArgumentError.value(initial, 'initial', 'Nothing is left of the initial state');
    _state = UnmodifiableListView<ElixirPage>(state);
    revalidate?.addListener(this.revalidate);
  }

  /// The most changes committed at once: a listener changing the state on every change is stopped there.
  static const int _maxCommands = 64;

  /// Tells controllers apart, e.g. in an `ElixirNotification`.
  final ElixirAlias? name;

  /// The rules applied to every change, in order: each guard receives the result of the previous one.
  final List<ElixirGuard> guards;

  final ElixirNavigationState _initial;
  final Listenable? _revalidate;
  final Queue<_Command> _queue = Queue<_Command>();

  /// The futures of [pushForResult], by page key.
  final Map<LocalKey, Completer<Object?>> _waiting = <LocalKey, Completer<Object?>>{};

  ElixirNavigationState _state = const <ElixirPage>[];
  bool _draining = false;
  bool _disposed = false;
  bool _notifyScheduled = false;

  /// The pages from the root to the visible one, unmodifiable.
  ElixirNavigationState get state => _state;

  @override
  ElixirNavigationState get value => _state;

  /// Rewrites the state with [fn]. Every other method is a shortcut for it.
  void change(ElixirChange fn) => _run((state) => (fn(state), const <LocalKey, Object?>{}));

  /// Adds [page] on top. A page with the same key that is already in the state moves to the top.
  void push(ElixirPage page) => change((state) => state..add(page));

  /// Adds [page] on top and completes when it leaves the state.
  ///
  /// Completes with the result given to [pop], [remove] or `Navigator.pop(context, result)`, and with `null` when the
  /// page is closed in another way, rejected by a guard, pushed for a result again or the controller is disposed.
  /// ```dart
  /// final confirmed = await controller.pushForResult<bool>(const ConfirmPage());
  /// ```
  Future<T?> pushForResult<T extends Object?>(ElixirPage page) {
    _waiting.remove(page.key)?.complete();
    if (_disposed) return Future<T?>.value();
    final completer = _waiting[page.key] = Completer<Object?>();
    push(page);
    return completer.future.then((result) => result is T ? result : null);
  }

  /// Removes the visible page, unless it is the only one, and completes its [pushForResult] with [result].
  ///
  /// It changes the state only: a route opened imperatively on top, e.g. with `showDialog`, stays. To close what the
  /// user sees, like the back button does, use `Navigator.maybePop(context)`.
  void pop([Object? result]) => _run((state) {
    if (state.length < 2) return (state, const <LocalKey, Object?>{});
    final page = state.removeLast();
    return (state, {page.key: result});
  });

  /// Removes the page with the key of [page] and completes its [pushForResult] with [result].
  void remove(ElixirPage page, [Object? result]) {
    final key = page.key;
    _run((state) => (state..removeWhere((other) => other.key == key), {key: result}));
  }

  /// Removes the pages above the topmost page with [alias]. Does nothing when there is none.
  void popUntil(ElixirAlias alias) => change((state) {
    final index = state.lastIndexWhere((page) => page.alias == alias);
    return index < 0 ? state : state.sublist(0, index + 1);
  });

  /// Removes the pages marked with [tag], see [ElixirPage.tags].
  void removeTag(String tag) => change((state) => state..removeWhere((page) => page.tags.contains(tag)));

  /// Returns to the initial state given to the constructor, validated by the guards again.
  void reset() => change((_) => List<ElixirPage>.of(_initial));

  /// Runs the guards on the current state again.
  void revalidate() => change((state) => state);

  void _run(_Command command) {
    if (_disposed) return;
    _queue.add(command);
    if (_draining) return;
    _draining = true;
    try {
      for (var committed = 0; _queue.isNotEmpty && !_disposed; committed++) {
        if (committed == _maxCommands) {
          _report(StateError('More than $_maxCommands changes in a row; the rest are dropped'), 'draining the queue');
          break;
        }
        _commit(_queue.removeFirst());
      }
    } finally {
      _queue.clear();
      _draining = false;
      _settle();
    }
  }

  void _commit(_Command command) {
    final previous = _state;
    final (ElixirNavigationState, Map<LocalKey, Object?>) change;
    try {
      change = command(List<ElixirPage>.of(previous));
    } on Object catch (error, stackTrace) {
      return _report(error, 'changing the state', stackTrace);
    }
    final (requested, results) = change;
    final next = _validate(previous, requested);
    if (_disposed) return;
    if (next.isEmpty) return _report(StateError('The navigation state cannot be empty'), 'committing $requested');
    if (listEquals(previous, next)) return;
    _state = UnmodifiableListView<ElixirPage>(List<ElixirPage>.of(next));
    _complete(previous, results);
    _notify();
  }

  ElixirNavigationState _validate(ElixirNavigationState from, ElixirNavigationState to) {
    var next = _dedupe(to);
    for (final guard in guards) {
      try {
        next = guard(from, List<ElixirPage>.of(next));
      } on Object catch (error, stackTrace) {
        _report(error, 'running $guard', stackTrace);
      }
    }
    return _dedupe(next);
  }

  /// Keeps the last page of every key, so pushing a page that is already in the state moves it to the top.
  static ElixirNavigationState _dedupe(ElixirNavigationState state) {
    final keys = <LocalKey>{};
    final unique = state.reversed.where((page) => keys.add(page.key)).toList().reversed.toList();
    return unique.length == state.length ? state : unique;
  }

  /// Completes the futures of the pages that have left the state with the results of the change.
  void _complete(ElixirNavigationState previous, Map<LocalKey, Object?> results) {
    if (_waiting.isEmpty) return;
    final keys = {for (final page in _state) page.key};
    for (final page in previous) {
      if (!keys.contains(page.key)) _waiting.remove(page.key)?.complete(results[page.key]);
    }
  }

  /// Completes with `null` the futures of the pages that never made it into the state, once the queue is drained.
  void _settle() {
    if (_waiting.isEmpty) return;
    final keys = {for (final page in _state) page.key};
    final orphans = _waiting.keys.where((key) => !keys.contains(key)).toList();
    for (final key in orphans) {
      _waiting.remove(key)?.complete();
    }
  }

  void _notify() {
    if (!hasListeners) return;
    // During the build, marking an ancestor of the building widget dirty throws: notify after the frame.
    if (SchedulerBinding.instance.schedulerPhase != SchedulerPhase.persistentCallbacks) return notifyListeners();
    if (_notifyScheduled) return;
    _notifyScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    }, debugLabel: 'ElixirController.notifyListeners');
  }

  void _report(Object error, String action, [StackTrace? stackTrace]) => FlutterError.reportError(
    FlutterErrorDetails(
      exception: error,
      stack: stackTrace ?? StackTrace.current,
      library: 'elixir',
      context: ErrorDescription('while $action in $this'),
    ),
  );

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _revalidate?.removeListener(revalidate);
    _queue.clear();
    final waiting = _waiting.values.toList();
    _waiting.clear();
    for (final completer in waiting) {
      completer.complete();
    }
    super.dispose();
  }

  @override
  String toString() => 'ElixirController(${name == null ? '' : '${name!.alias}: '}${_state.join(' > ')})';
}
