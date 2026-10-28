import 'package:flutter/widgets.dart';

import 'page.dart';

/// {@template elixir_dialog_page}
/// Shows an [ElixirPage] as a dialog: centered above a barrier, with a fade.
///
/// The page is tagged [ElixirPage.modalTag], and its route is page-based and built on widgets only.
/// ```dart
/// final class ConfirmPage extends AppPage with ElixirDialogPage {
///   const ConfirmPage() : super(child: const ConfirmDialog());
///
///   @override
///   ElixirAlias get alias => Routes.confirm;
/// }
///
/// final confirmed = await controller.pushForResult<bool>(const ConfirmPage());
/// // in the dialog: Navigator.pop(context, true)
/// ```
/// {@endtemplate}
base mixin ElixirDialogPage on ElixirPage {
  /// Whether a tap on the barrier closes the dialog.
  bool get barrierDismissible => true;

  /// The color of the barrier.
  Color get barrierColor => const Color(0x8A000000);

  /// The semantic label of the barrier.
  String get barrierLabel => 'Dismiss';

  @override
  Set<String> get tags => {...super.tags, ElixirPage.modalTag};

  @override
  Route<Object?> createRoute(BuildContext context) => _DialogRoute(this);
}

/// {@template elixir_sheet_page}
/// Shows an [ElixirPage] as a bottom sheet: sliding up above a barrier, closed by a downward drag.
///
/// The page is tagged [ElixirPage.modalTag], and its route is page-based and built on widgets only.
/// ```dart
/// final class FiltersPage extends AppPage with ElixirSheetPage {
///   const FiltersPage() : super(child: const FiltersSheet());
///
///   @override
///   ElixirAlias get alias => Routes.filters;
/// }
/// ```
/// {@endtemplate}
base mixin ElixirSheetPage on ElixirPage {
  /// Whether a tap on the barrier closes the sheet.
  bool get barrierDismissible => true;

  /// The color of the barrier.
  Color get barrierColor => const Color(0x8A000000);

  /// The semantic label of the barrier.
  String get barrierLabel => 'Dismiss';

  /// Whether a downward drag closes the sheet.
  bool get enableDrag => true;

  @override
  Set<String> get tags => {...super.tags, ElixirPage.modalTag};

  @override
  Route<Object?> createRoute(BuildContext context) => _SheetRoute(this);
}

final class _DialogRoute extends PopupRoute<Object?> {
  _DialogRoute(ElixirDialogPage page) : super(settings: page);

  ElixirDialogPage get _page => settings as ElixirDialogPage;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color get barrierColor => _page.barrierColor;

  @override
  String get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 150);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: SafeArea(child: Center(child: _page.child)),
      );

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
    child: child,
  );
}

final class _SheetRoute extends PopupRoute<Object?> {
  _SheetRoute(ElixirSheetPage page) : super(settings: page);

  /// The downward speed, in logical pixels per second, that closes the sheet whatever its position.
  static const double _closingVelocity = 700;

  ElixirSheetPage get _page => settings as ElixirSheetPage;

  @override
  bool get barrierDismissible => _page.barrierDismissible;

  @override
  Color get barrierColor => _page.barrierColor;

  @override
  String get barrierLabel => _page.barrierLabel;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 250);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      Semantics(
        scopesRoute: true,
        explicitChildNodes: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Builder(
            builder: (context) => GestureDetector(
              onVerticalDragStart: _page.enableDrag ? (_) => navigator?.didStartUserGesture() : null,
              onVerticalDragUpdate: _page.enableDrag ? (details) => _drag(details, context.size?.height) : null,
              onVerticalDragEnd: _page.enableDrag ? (details) => _settle(details.primaryVelocity ?? 0) : null,
              onVerticalDragCancel: _page.enableDrag ? () => _settle(0) : null,
              child: _page.child,
            ),
          ),
        ),
      );

  // ponytail: the drag follows the finger linearly; the slide keeps no curve, so it does not jump when a drag starts.
  void _drag(DragUpdateDetails details, double? height) {
    if (height == null || height == 0) return;
    controller!.value -= details.primaryDelta! / height;
  }

  void _settle(double velocity) {
    final navigator = this.navigator;
    if (navigator == null || !isActive) return;
    if (velocity > _closingVelocity || (velocity >= 0 && controller!.value < 0.5)) {
      navigator.pop();
    } else {
      controller!.forward();
    }
    navigator.didStopUserGesture();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => SlideTransition(
    position: animation.drive(Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)),
    child: child,
  );
}
