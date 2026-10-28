import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'controller.dart';
import 'page.dart';

/// Handles the system back button instead of `navigator.maybePop()`; returns whether the press was handled.
typedef ElixirBackHandler = Future<bool> Function(NavigatorState navigator);

/// {@template elixir}
/// Renders an [ElixirController] with a [Navigator].
///
/// The widget is a thin adapter: it shows the pages of the controller, reports the pages the user closed (a swipe, a
/// barrier tap, `Navigator.pop(context, result)`) back with `controller.remove`, and handles the system back button.
/// ```dart
/// MaterialApp(builder: (context, _) => Elixir(controller: controller));
/// ```
///
/// Every committed change is dispatched as an [ElixirNotification], which bubbles up through the outer Elixirs: one
/// [NotificationListener] above the root Elixir hears every navigator of the app.
///
/// The back button goes to the visible nested Elixirs first, the newest first, then to [onBackButtonPressed], by
/// default `navigator.maybePop()`. So a dialog or a sheet on top closes first, `PopScope` is respected, and the last
/// page lets the platform close the app. A nested Elixir is visible while its route is current and it is not hidden
/// by a [Visibility], e.g. an inactive tab of an [IndexedStack].
/// {@endtemplate}
class Elixir extends StatefulWidget {
  /// {@macro elixir}
  const Elixir({
    required this.controller,
    this.observers = const <NavigatorObserver>[],
    this.transitionDelegate = const DefaultTransitionDelegate<Object?>(),
    this.onBackButtonPressed,
    this.restorationScopeId,
    this.reportsRouteUpdateToEngine = false,
    super.key,
  });

  /// The owner of the pages.
  final ElixirController controller;

  /// Observers of the underlying [Navigator].
  final List<NavigatorObserver> observers;

  /// Decides how the routes are animated when the pages change.
  final TransitionDelegate<Object?> transitionDelegate;

  /// Replaces the default reaction to the back button, `navigator.maybePop()`.
  ///
  /// Called only when the press reaches this Elixir: no visible nested Elixir has handled it.
  /// ```dart
  /// onBackButtonPressed: (navigator) async {
  ///   if (controller.state.last.tags.contains('checkout')) {
  ///     controller.popUntil(Routes.cart);
  ///     return true;
  ///   }
  ///   return navigator.maybePop();
  /// },
  /// ```
  final ElixirBackHandler? onBackButtonPressed;

  /// Restores the state of the navigator when given, see [Navigator.restorationScopeId].
  final String? restorationScopeId;

  /// Whether the navigator reports the route changes to the engine, e.g. to the browser address bar.
  final bool reportsRouteUpdateToEngine;

  /// The controller of the closest Elixir above [context], if any.
  static ElixirController? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<_ElixirScope>()?.state.widget.controller;

  /// The controller of the closest Elixir above [context].
  static ElixirController of(BuildContext context) => maybeOf(context) ?? _notFound();

  /// The pages of the closest Elixir above [context]; the widget is rebuilt when they change.
  static ElixirNavigationState stackOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ElixirScope>()?.pages ?? _notFound();

  static Never _notFound() => throw FlutterError('No Elixir found above this context.');

  @override
  State<Elixir> createState() => _ElixirState();
}

class _ElixirState extends State<Elixir> with WidgetsBindingObserver {
  /// The Elixirs that take the back button from the binding: they are not nested into another Elixir.
  static final Set<_ElixirState> _roots = <_ElixirState>{};

  late final _Tracker _tracker = _Tracker((key, result) => _popped[key] = result);

  /// The results given to `Navigator.pop`, waiting for [_handleDidRemovePage].
  final Map<LocalKey, Object?> _popped = <LocalKey, Object?>{};

  late List<NavigatorObserver> _observers;
  late ElixirNavigationState _last;

  _ElixirState? _parent;

  /// The nested Elixirs, in the order they were mounted.
  final List<_ElixirState> _children = <_ElixirState>[];

  /// The navigator a root Elixir is shown in, e.g. the one of a `MaterialApp`.
  NavigatorState? _host;

  /// The route of the outer navigator this Elixir is shown in.
  ModalRoute<Object?>? _route;
  bool _shown = true;
  bool _reportScheduled = false;

  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    _observers = <NavigatorObserver>[_tracker, ...widget.observers];
    _last = widget.controller.state;
    widget.controller.addListener(_handleChange);
    _register();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Only the back button depends on these: the guards never run here.
    _route = ModalRoute.of(context);
    _shown = Visibility.of(context);
    _reportBackButton();
  }

  @override
  void didUpdateWidget(covariant Elixir oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.observers, oldWidget.observers)) {
      _observers = <NavigatorObserver>[_tracker, ...widget.observers];
    }
    if (!identical(widget.controller, oldWidget.controller)) {
      oldWidget.controller.removeListener(_handleChange);
      widget.controller.addListener(_handleChange);
      _last = widget.controller.state;
      _popped.clear();
    }
    _reportBackButton();
  }

  @override
  void activate() {
    super.activate();
    _register();
    _reportBackButton();
  }

  @override
  void deactivate() {
    final parent = _parent;
    _unregister();
    // The Elixirs left behind may be the ones handling the back button now.
    (parent ?? _roots.firstOrNull)?._reportBackButton();
    if (parent == null && _roots.isEmpty) _reportNoElixirLeft();
    super.deactivate();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleChange);
    super.dispose();
  }
  /* #endregion */

  void _handleChange() {
    final previous = _last;
    final next = _last = widget.controller.state;
    if (!mounted || identical(previous, next)) return;
    setState(() {});
    try {
      ElixirNotification(widget.controller, previous, next).dispatch(context);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'elixir',
          context: ErrorDescription('while dispatching an ElixirNotification of ${widget.controller}'),
        ),
      );
    }
  }

  /// Called by the [Navigator] for a page the user or the framework closed.
  void _handleDidRemovePage(Page<Object?> page) {
    if (page is! ElixirPage) return;
    final controller = widget.controller..remove(page, _popped.remove(page.key));
    // A guard has kept the page that the navigator already dropped: build it again.
    if (mounted && controller.state.any((other) => other.key == page.key)) setState(() {});
  }

  /* #region Back button */
  void _register() {
    if (context.getInheritedWidgetOfExactType<_ElixirScope>()?.state case final parent?) {
      _parent = parent.._children.add(this);
    } else {
      _host = Navigator.maybeOf(context);
      _roots.add(this);
      WidgetsBinding.instance.addObserver(this);
    }
  }

  void _unregister() {
    if (_parent case final parent?) {
      parent._children.remove(this);
      _parent = null;
    } else {
      _roots.remove(this);
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  Future<bool> didPopRoute() => _visible ? _handleBackButton() : SynchronousFuture<bool>(false);

  bool get _visible => mounted && _shown && (_route?.isCurrent ?? true);

  Future<bool> _handleBackButton() async {
    for (final child in _children.reversed.toList(growable: false)) {
      if (child._visible && await child._handleBackButton()) return true;
    }
    final navigator = _tracker.navigator;
    if (!mounted || navigator == null) return false;
    return (widget.onBackButtonPressed ?? _maybePop)(navigator);
  }

  static Future<bool> _maybePop(NavigatorState navigator) => navigator.maybePop();

  /// Whether a press reaching this Elixir would be handled, decided the way [_handleBackButton] does it.
  bool get _canHandlePop {
    if (!_visible) return false;
    if (_children.any((child) => child._canHandlePop) || widget.onBackButtonPressed != null) return true;
    final navigator = _tracker.navigator;
    return navigator != null && (navigator.canPop() || _tracker.top?.popDisposition == RoutePopDisposition.doNotPop);
  }

  /// The navigators report only themselves, so a nested one and its parent overwrite each other's report: swallow
  /// them, and let the roots report for the whole tree.
  bool _handleNavigationNotification(NavigationNotification notification) {
    _reportBackButton();
    return true;
  }

  /// Tells the platform whether the app handles the back button; without it, the predictive back gesture of Android
  /// closes the app without ever calling [didPopRoute].
  void _reportBackButton() {
    // The navigators report from the post frame callbacks: answer in the same frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.postFrameCallbacks) return _dispatchBackButton();
    if (_reportScheduled) return;
    _reportScheduled = true;
    SchedulerBinding.instance
      ..addPostFrameCallback((_) {
        _reportScheduled = false;
        _dispatchBackButton();
      }, debugLabel: 'Elixir.reportBackButton')
      ..ensureVisualUpdate();
  }

  void _dispatchBackButton() {
    if (!mounted) return;
    if (_parent case final parent?) return parent._dispatchBackButton();
    // Deactivated, e.g. while it moves with a global key.
    if (!_roots.contains(this)) return;
    NavigationNotification(canHandlePop: _roots.any((root) => root._canHandlePop)).dispatch(context);
  }

  /// Withdraws the claim of the last root Elixir, which nothing else would replace.
  void _reportNoElixirLeft() {
    final host = _host;
    if (host == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_roots.isEmpty && host.mounted) NavigationNotification(canHandlePop: host.canPop()).dispatch(host.context);
    }, debugLabel: 'Elixir.reportNoElixirLeft');
  }
  /* #endregion */

  @override
  Widget build(BuildContext context) => _ElixirScope(
    state: this,
    pages: widget.controller.state,
    child: NotificationListener<NavigationNotification>(
      onNotification: _handleNavigationNotification,
      child: Navigator(
        // A new list, so the navigator also brings back a page a guard kept after the user closed it.
        pages: List<Page<Object?>>.of(widget.controller.state),
        onDidRemovePage: _handleDidRemovePage,
        observers: _observers,
        transitionDelegate: widget.transitionDelegate,
        restorationScopeId: widget.restorationScopeId,
        reportsRouteUpdateToEngine: widget.reportsRouteUpdateToEngine,
      ),
    ),
  );
}

/// Links an Elixir with its controller below and with the nested Elixirs.
class _ElixirScope extends InheritedWidget {
  const _ElixirScope({required this.state, required this.pages, required super.child});

  final _ElixirState state;

  /// The pages this Elixir was built with.
  final ElixirNavigationState pages;

  @override
  bool updateShouldNotify(covariant _ElixirScope oldWidget) => !identical(oldWidget.pages, pages);
}

/// {@template elixir_notification}
/// A change committed by the controller of an [Elixir], bubbling up through the widget tree.
///
/// ```dart
/// NotificationListener<ElixirNotification>(
///   onNotification: (notification) {
///     log('${notification.controller.name}: ${notification.next}');
///     return false; // let it reach the listeners above
///   },
///   child: Elixir(controller: controller),
/// );
/// ```
///
/// A change committed during a build is dispatched after the frame, merged with the following ones of that frame.
/// {@endtemplate}
final class ElixirNotification extends Notification {
  /// {@macro elixir_notification}
  const ElixirNotification(this.controller, this.previous, this.next);

  /// The controller that committed the change; `controller.name` tells the Elixirs apart.
  final ElixirController controller;

  /// The pages before the change.
  final ElixirNavigationState previous;

  /// The pages after the change.
  final ElixirNavigationState next;

  /// The pages whose keys are new.
  ElixirNavigationState get added => _without(next, previous);

  /// The pages whose keys are gone.
  ElixirNavigationState get removed => _without(previous, next);

  static ElixirNavigationState _without(ElixirNavigationState pages, ElixirNavigationState other) {
    final keys = {for (final page in other) page.key};
    return [
      for (final page in pages)
        if (!keys.contains(page.key)) page,
    ];
  }

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$controller');
  }
}

/// Reaches the [NavigatorState], keeps the visible route and catches the results given to `Navigator.pop`.
class _Tracker extends NavigatorObserver {
  _Tracker(this._onPop);

  final void Function(LocalKey key, Object? result) _onPop;

  /// The visible route, to see whether a `PopScope` blocks the back button.
  Route<Object?>? top;

  @override
  void didChangeTop(Route<Object?> topRoute, Route<Object?>? previousTopRoute) => top = topRoute;

  @override
  void didPush(Route<Object?> route, Route<Object?>? previousRoute) => _track(route);

  @override
  void didReplace({Route<Object?>? newRoute, Route<Object?>? oldRoute}) {
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<Object?> route) {
    if (route case ModalRoute<Object?>(settings: ElixirPage(:final key))) {
      route.registerPopEntry(_PopResult(key, _onPop));
    }
  }
}

/// A [PopEntry] that never blocks a pop and only records its result.
class _PopResult extends PopEntry<Object?> {
  _PopResult(this._key, this._onPop);

  final LocalKey _key;
  final void Function(LocalKey key, Object? result) _onPop;

  @override
  ValueListenable<bool> get canPopNotifier => const _AlwaysTrue();

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {
    if (didPop) _onPop(_key, result);
  }
}

/// A `true` that never changes, so it keeps no listeners of the routes.
class _AlwaysTrue implements ValueListenable<bool> {
  const _AlwaysTrue();

  @override
  bool get value => true;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
