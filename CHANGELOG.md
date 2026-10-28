## 0.5.0

A new architecture: one controller owns the navigation state, guards are pure rules, and the `Elixir` widget is a thin
adapter. See "Migrating from 0.4" in the README.

- **Breaking:** `ElixirController` replaces `ValueNotifier<ElixirNavigationState>`, `Elixir.controlled` and
  `Elixir(pages:)`; `Elixir` now takes `controller` only. `context.elixir` returns the controller
- **Breaking:** guards move to the controller and become `ElixirGuard` objects with `call(from, to)`; they no longer
  receive a `BuildContext`. `revalidate` moves to the controller as well
- **Breaking:** `ElixirObserver`, `ElixirObserver$NavigatorImpl`, `ElixirListener` and the `listeners` parameter are
  removed; listen to the `ElixirNotification` that every change bubbles up the tree
- **Breaking:** `onBackButtonPressed` is `Future<bool> Function(NavigatorState navigator)`; by default the back button
  calls `navigator.maybePop()`, so dialogs and `PopScope` are respected and the root page lets the app close
- **Breaking:** `ElixirPage` extends `Page<Object?>`, takes no `name`, has optional `tags`, compares by identity, and
  its default key is `name?a=1&b` built from the argument values instead of their identity hash
- **Breaking:** `reset()` takes no argument and returns to the initial state; `popUntil` stops at the topmost page with
  the alias; `Elixir.stateOf`, `Elixir.navigatorOf` and `ElixirControllerExtension` are removed
- **Breaking:** the navigator no longer uses the `elixir_navigator` restoration scope by default; pass
  `restorationScopeId`
- **Breaking:** `CupertinoBackGestureDetector` and `CupertinoBackGestureController` moved out of the package into the
  example (`example/lib/src/common/cupertino_back/`); copy them into an app that needs the swipe on a custom route
- Added `pushForResult`, `pop(result)` and `remove(page, result)`; `Navigator.pop(context, result)` completes
  `pushForResult` too
- Added `ElixirDialogPage` and `ElixirSheetPage` (widgets-only, page-based), `ElixirPage.modalTag`, `RootGuard`,
  `ModalGuard`, `ElixirPageRoute`, `Elixir.stackOf`, `removeTag`, `remove` and `context.maybeElixir`
- Changes are deduplicated by key (the last page wins), queued when requested during a change, isolated from failing
  guards, and notified after the frame when committed during a build
- A page the user closed but a guard kept is shown again; the root Elixir reports `canHandlePop` for the whole tree,
  newest nested Elixir first
- MIT license, real pubspec metadata, `flutter: ">=3.35.0"`, CI, and tests for every behavior above

## 0.4.0

- **Breaking:** `ElixirPage.createRoute` no longer defaults to `MaterialPageRoute`; every page (or a shared base page class) must implement it
- The package now imports only `package:flutter/widgets.dart`, so it no longer depends on Material and works with Cupertino or custom routes
- Example: light/dark theme toggle and Cupertino page transitions through `ThemeData.pageTransitionsTheme`

## 0.3.0

- **Breaking:** `ElixirStateObserver` replaced by `ElixirObserver`. `context.elixir.observer` now returns one observer created by the root Elixir and shared with every nested Elixir; listeners are `(elixir, previous, next)` callbacks instead of `VoidCallback`
- **Breaking:** Removed navigation history (`history`, `setHistory`, `ElixirHistoryEntry`, `maxHistoryLength`)
- Added `ElixirListener` typedef and `listeners` parameter on `Elixir`, called for that Elixir and every Elixir nested inside it
- Added optional `name` (`ElixirAlias?`) parameter on `Elixir` and `ElixirState.name` to tell Elixirs apart, e.g. in listeners
- System back button now goes to the innermost active nested Elixir first; a nested Elixir with a single page, or whose `onBackButtonPressed` returns `handled: false`, passes it to its parent
- Nested Elixirs under a covered route or in a hidden `IndexedStack` tab are skipped when handling the back button
- Added widget tests for nested back button handling and observers

## 0.2.0

- **Breaking:** `ElixirPage` now requires an `alias` field of type `ElixirAlias`; `name` is derived from `alias.alias`
- **Breaking:** Minimum SDK constraint raised to `^3.9.1`
- Added `ElixirAlias` interface for enum-based route identification
- Added `popUntil(ElixirAlias)` method to `ElixirState` and `ElixirControllerExtension`
- Added `ElixirControllerExtension` on `ValueNotifier<ElixirNavigationState>` with `change()` and `popUntil()` for programmatic navigation outside the widget tree
- Added `revalidate` parameter on `Elixir` widget to re-run guards when a `Listenable` fires
- Added `onBackButtonPressed` callback for custom system back button handling
- Added `ElixirStateObserver` with timestamped navigation history (up to 10,000 entries)
- Added `CupertinoBackGestureDetector` and `CupertinoBackGestureController` for iOS-style swipe-back gestures
- Added static access helpers: `Elixir.of`, `Elixir.maybeOf`, `Elixir.stateOf`, `Elixir.navigatorOf`
- Improved `ElixirPage` key generation using name and arguments hash
- Improved equality and hashCode implementations in `ElixirPage`
- Updated `flutter_lints` to `^6.0.0`
- Added `public_member_api_docs` lint rule and enhanced documentation across all public APIs

## 0.0.2

- Added Elixir controller extension

## 0.0.1

- Initial configuration
