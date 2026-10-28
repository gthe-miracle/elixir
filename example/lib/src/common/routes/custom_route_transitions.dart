import 'package:flutter/material.dart';

import '../cupertino_back/cupertino_back_gesture.dart';
import 'routes.dart';

/// {@template custom_material_route}
/// CustomMaterialRoute widget.
/// {@endtemplate}
class CustomMaterialRoute extends PageRoute<Object?> {
  /// {@macro custom_material_route}
  CustomMaterialRoute({required AppPage page}) : super(settings: page);

  /// {@macro custom_material_route}
  AppPage get page => settings as AppPage;

  @override
  bool get popGestureEnabled => true;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      page.child;

  @override
  bool get maintainState => true;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => const ZoomPageTransitionsBuilder().buildTransitions(
    this,
    context,
    animation,
    secondaryAnimation,
    CupertinoBackGestureDetector<Object?>(
      enabledCallback: () => popGestureEnabled,
      onStartPopGesture: () => CupertinoBackGestureController<Object?>(
        navigator: navigator!,
        getIsActive: () => isActive,
        getIsCurrent: () => isCurrent,
        controller: controller!, // protected access
      ),
      child: child,
    ),
  );
}
