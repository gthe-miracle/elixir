# Elixir

Declarative Navigator 2.0 navigation for Flutter. The navigation state is a list of pages owned by one controller:
every change goes through pure guard rules, and a thin widget renders it.

```dart
controller.change((state) => [...state, const SettingsPage()]);
```

## Features

- ✅ The navigation state is a plain `List<ElixirPage>`; rewrite it and the screens follow
- ✅ One owner, `ElixirController`, that works and tests without widgets
- ✅ Guards: pure `(from, to) => to` rules applied to every change, re-run by a `Listenable`
- ✅ Results: `await controller.pushForResult<bool>(page)`, completed by `pop(result)` or `Navigator.pop(context, result)`
- ✅ Dialogs and bottom sheets as pages (`ElixirDialogPage`, `ElixirSheetPage`)
- ✅ Nested Elixirs with innermost, newest-first system back handling and correct Android predictive back
- ✅ One `NotificationListener` at the root hears every navigator of the app
- ✅ No Material dependency: pages build any `Route` (Material, Cupertino or custom)

## Getting Started

```yaml
dependencies:
  elixir:
    git:
      url: https://github.com/Miracle-Blue/elixir.git
```

## Usage

### 1. Aliases

```dart
enum Routes implements ElixirAlias {
  app('app'), // names the root Elixir
  home('home'),
  product('product'),
  settings('settings'),
  confirm('confirm'),
  filters('filters');

  const Routes(this.alias);

  @override
  final String alias;
}
```

### 2. Pages

A page is an immutable value and also the `Page` given to the `Navigator`. Implement `alias` and `createRoute`, usually
once in a sealed base page:

```dart
@immutable
sealed class AppPage extends ElixirPage {
  const AppPage({required super.child, super.arguments, super.key});

  @override
  Route<Object?> createRoute(BuildContext context) => AppPageRoute(this);
}

/// Material transitions from the theme. Page-based: a new page under the same key updates the screen.
final class AppPageRoute extends PageRoute<Object?> with MaterialRouteTransitionMixin<Object?> {
  AppPageRoute(AppPage page) : super(settings: page);

  @override
  Widget buildContent(BuildContext context) => (settings as AppPage).child;

  @override
  bool get maintainState => true;
}

final class HomePage extends AppPage {
  const HomePage() : super(child: const HomeScreen());

  @override
  ElixirAlias get alias => Routes.home;
}

final class ProductPage extends AppPage {
  ProductPage(this.id) : super(child: ProductScreen(id: id));

  final int id;

  // Parameters kept in fields need their own key, otherwise every product is one screen.
  @override
  LocalKey get key => ValueKey<String>('product/$id');

  @override
  ElixirAlias get alias => Routes.product;
}
```

Without Material, `ElixirPageRoute(this)` is a widgets-only page-based route with a `transitionsBuilder` hook.

The route must be page-based: it reads `(settings as ElixirPage).child` on every build. A `MaterialPageRoute(builder:)`
captures the first child, so a new instance of the page with the same key would never reach the screen.

### 3. Controller and widget

```dart
class _AppState extends State<App> {
  late final ElixirController _controller = ElixirController(
    [const HomePage()],
    guards: const [RootGuard(HomePage()), ModalGuard()],
    name: Routes.app,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    builder: (context, _) => Elixir(controller: _controller),
  );
}
```

### 4. Navigate

`context.elixir` is the controller of the closest Elixir:

```dart
context.elixir.push(const SettingsPage());            // a page already in the state moves to the top
context.elixir.pop();                                  // never removes the last page
context.elixir.popUntil(Routes.home);                  // to the topmost page with the alias
context.elixir.removeTag('checkout');
context.elixir.reset();                                // back to the initial state, through the guards
context.elixir.change((state) => [state.first, ProductPage(1)]);

final confirmed = await context.elixir.pushForResult<bool>(const ConfirmPage());
```

Inside a page, the usual `Navigator.maybePop(context)` and `Navigator.pop(context, result)` work too: the controller
learns about every page the user closes.

## Guards

A guard receives the committed state `from` and the requested state `to`, and returns the state to commit. Return
`to`, a redirect, or `from` to cancel. Guards see neither the controller nor a `BuildContext`: they are pure rules,
testable as functions. Their dependencies go to their constructor, and `revalidate` re-runs them:

```dart
final controller = ElixirController(
  [const HomePage()],
  guards: [
    const RootGuard(HomePage()),
    ElixirGuard((from, to) => auth.isSignedIn ? to : [const SignInPage()]),
  ],
  revalidate: auth, // a Listenable
);
```

Every change runs this pipeline:
1. dedupe by key, keeping the last page;
2. the guards in order;
3. dedupe again.

An empty result is reported and rejected. A result equal to the current state is ignored. A guard that throws is
reported to `FlutterError` and skipped. A guard with state of its own implements `ElixirGuard`.

Built-in guards:
- `RootGuard(page)` keeps a page at the bottom.
- `ModalGuard()` keeps dialogs and sheets above the screens.

To stop the user from closing a page, use `PopScope`.

## Dialogs and sheets

A modal is a page: add a mixin to it.

```dart
final class ConfirmPage extends AppPage with ElixirDialogPage {
  const ConfirmPage() : super(child: const ConfirmDialog());

  @override
  ElixirAlias get alias => Routes.confirm;
}

final class FiltersPage extends AppPage with ElixirSheetPage {
  const FiltersPage() : super(child: const FiltersSheet());

  @override
  ElixirAlias get alias => Routes.filters;
}
```

Both mixins tag the page `ElixirPage.modalTag`, so `controller.removeTag(ElixirPage.modalTag)` closes every modal at
once. Their routes are widgets-only and page-based. The mixins expose these getters:
- `barrierDismissible`
- `barrierColor`
- `barrierLabel`
- `enableDrag` (sheet only)

## Observing navigation

Every committed change is dispatched as an `ElixirNotification` that bubbles up through the outer Elixirs. `listener`
on an Elixir hears that Elixir and every Elixir nested inside it, so `listener` on the root hears the whole app:

```dart
Elixir(
  controller: controller,
  listener: (n) => analytics.screens(n.controller.name, added: n.added, removed: n.removed),
)
```

`controller.name` tells the Elixirs apart. `listener` never stops the notification, and an error it throws is reported
instead of breaking the listeners above.

`listener` is a shortcut for a `NotificationListener<ElixirNotification>` wrapped around the Elixir. Use the
`NotificationListener` directly to hear the changes from a widget above the Elixir, or to stop one by returning `true`.

You can also watch the state directly:
- `ElixirController` is a `ValueListenable<List<ElixirPage>>`, so it works with `ListenableBuilder` and with code
  outside the widget tree.
- `Elixir.stackOf(context)` rebuilds a widget on every change.

## Back button

The system back button goes to the visible nested Elixirs first, newest first, then to `navigator.maybePop()`. So:
- an open dialog or sheet closes first;
- `PopScope` is respected;
- a nested Elixir with one page hands the press to its parent;
- the root page lets the platform close the app.

A nested Elixir under a covered route, or in a hidden `IndexedStack` tab, is skipped. The root Elixir reports one
`canHandlePop` for the whole tree, so Android's predictive back gesture only closes the app when nothing can go back.

```dart
Elixir(
  controller: controller,
  onBackButtonPressed: (navigator) async {
    if (controller.state.last.tags.contains('checkout')) {
      controller.popUntil(Routes.home);
      return true;
    }
    return navigator.maybePop();
  },
)
```

### iOS swipe-back gesture

The example has a widgets-only port of Flutter's iOS edge swipe for custom routes: copy
`example/lib/src/common/cupertino_back/cupertino_back_gesture.dart` and see how
`example/lib/src/common/routes/custom_route_transitions.dart` uses it. Routes built with
`MaterialRouteTransitionMixin` or `CupertinoRouteTransitionMixin` already get the swipe from the theme.

## Core API

### ElixirPage

| Member          | Type                   | Description                                                           |
| --------------- | ---------------------- | --------------------------------------------------------------------- |
| `child`         | `Widget`               | The content of the page                                               |
| `alias`         | `ElixirAlias`          | Required; usually an enum value                                       |
| `name`          | `String`               | `alias.alias`                                                         |
| `tags`          | `Set<String>`          | Optional marks, used by `removeTag` and `ModalGuard`                  |
| `arguments`     | `Map<String, Object?>` | Optional; empty by default                                            |
| `key`           | `LocalKey`             | The given key, else `name` or `name?a=1&b` (escaped)                  |
| `createRoute()` | `Route<Object?>`       | Required; must be page-based                                          |

Pages compare by identity; the controller identifies them by `key`.

### ElixirController

| Member                         | Description                                                           |
| ------------------------------ | --------------------------------------------------------------------- |
| `ElixirController(initial, …)` | `guards`, `revalidate` (`Listenable`), `name` (`ElixirAlias`)         |
| `state` / `value`              | The current pages, unmodifiable                                       |
| `change(fn)`                   | Rewrites the state; every other method is a shortcut for it           |
| `push(page)`                   | Adds a page on top, or moves its key to the top                       |
| `pushForResult<T>(page)`       | Pushes and completes when the page leaves, with its result or `null`  |
| `pop([result])`                | Removes the top page unless it is the last one                        |
| `remove(page, [result])`       | Removes the page with that key                                        |
| `popUntil(alias)`              | Removes the pages above the topmost page with the alias               |
| `removeTag(tag)`               | Removes the pages with the tag                                        |
| `reset()`                      | Returns to the initial state, through the guards                      |
| `revalidate()`                 | Runs the guards on the current state again                            |

A change requested while another one is committed (from a listener, for example) is queued and applied after it. After
64 changes in a row the rest are reported and dropped.

### Elixir

| Parameter                    | Type                         | Description                                         |
| ---------------------------- | ---------------------------- | --------------------------------------------------- |
| `controller`                 | `ElixirController`           | Required                                            |
| `listener`                   | `ElixirListener?`            | Changes of this Elixir and of the nested ones       |
| `observers`                  | `List<NavigatorObserver>`    | Observers of the underlying `Navigator`             |
| `transitionDelegate`         | `TransitionDelegate<Object?>`| Defaults to `DefaultTransitionDelegate`             |
| `onBackButtonPressed`        | `ElixirBackHandler?`         | Replaces `navigator.maybePop()`                     |
| `restorationScopeId`         | `String?`                    | Enables state restoration of the navigator          |
| `reportsRouteUpdateToEngine` | `bool`                       | Defaults to `false`                                 |

Static access works as follows:
- `Elixir.of(context)` and `Elixir.maybeOf(context)` return the controller, the same as `context.elixir` and
  `context.maybeElixir`;
- `Elixir.stackOf(context)` returns the pages and rebuilds on every change.

## Design

| Rule | What it means |
| --- | --- |
| Guards are pure business rules | They run only inside the controller, never during a build, so no change is ever committed mid-frame. |
| Data flows one way | The controller knows no widgets. The widget renders the pages, and reports back only the pages the user closed. |
| Back is the Navigator's back | Dialogs, `PopScope` and `Page.canPop` work without special cases. |
| The page is the `Page` | The Navigator's own key diff keeps routes and their state. |
| A change carries its results | A pop result travels with the change that removed the page. |

## Migrating from 0.4

| 0.4 | 0.5 |
| --- | --- |
| `ValueNotifier<ElixirNavigationState>` + `Elixir.controlled(controller:)` / `Elixir(pages:)` | `ElixirController(pages, guards:, revalidate:, name:)` + `Elixir(controller:)` |
| `guards: [(context, state) => …]` on the widget | `guards: [ElixirGuard((from, to) => …)]` on the controller; read dependencies when you create the controller |
| `state.toSet().toList()` guard | Built in: the last page of each key wins |
| `context.elixir` → `ElixirState` | `context.elixir` → `ElixirController` |
| `listeners: [(elixir, previous, next) {}]` | `listener: (notification) {}` |
| `context.elixir.observer.addListener(…)` | `listener` on the root Elixir, or a `NotificationListener<ElixirNotification>` above it |
| `onBackButtonPressed: (state) => (state:, handled:)` | `onBackButtonPressed: (navigator) async => …` |
| `super(name: …, child: …)`, required `tags`, `==` override | `super(child: …)`; `tags` optional; no `==` override |
| `Route<void> createRoute` with `MaterialPageRoute(builder:)` | `Route<Object?> createRoute` with a page-based route |
| `reset(page)` | `reset()` |
| `Elixir.stateOf` / `Elixir.navigatorOf` | `Elixir.stackOf` / `Navigator.of(pageContext)` |

## Example

See [example/](example/) for an app with:
- a nested Elixir;
- a dialog page that returns a result;
- a sheet page;
- a custom swipe-back route.

## License

MIT, see [LICENSE](LICENSE).

## Author

Created and maintained by [Miracle-Blue](https://github.com/Miracle-Blue).
