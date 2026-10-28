import 'dart:math' show max;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// This is the widget side of [CupertinoBackGestureController].
///
/// This widget provides a gesture recognizer which, when it determines the
/// route can be closed with a back gesture, creates the controller and
/// feeds it the input from the gesture recognizer.
///
/// The gesture data is converted from absolute coordinates to logical
/// coordinates by this widget.
///
/// The type `T` specifies the return type of the route with which this gesture
/// detector is associated.
class CupertinoBackGestureDetector<T> extends StatefulWidget {
  /// {@macro cupertino_back_gesture_detector}
  /// ```dart
  /// CupertinoBackGestureDetector<T>(
  ///   enabledCallback: () => true,
  ///   onStartPopGesture: () => CupertinoBackGestureController(
  ///     navigator: navigator,
  ///     controller: controller,
  ///     getIsActive: () => isActive,
  ///     getIsCurrent: () => isCurrent,
  ///   ),
  ///   child: child,
  /// );
  /// ```
  const CupertinoBackGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
    super.key,
  });

  /// The child widget.
  final Widget child;

  /// The callback function that will be called to check if the gesture is enabled.
  final ValueGetter<bool> enabledCallback;

  /// The callback function that will be called to start the pop gesture.
  ///
  /// It must return a [CupertinoBackGestureController] instance.
  /// ```dart
  /// onStartPopGesture = CupertinoBackGestureController(
  ///   navigator: navigator,
  ///   controller: controller,
  ///   getIsActive: () => isActive,
  ///   getIsCurrent: () => isCurrent,
  /// );
  /// ```
  final ValueGetter<CupertinoBackGestureController<T>> onStartPopGesture;

  @override
  State<CupertinoBackGestureDetector<T>> createState() => _CupertinoBackGestureDetectorState<T>();
}

class _CupertinoBackGestureDetectorState<T> extends State<CupertinoBackGestureDetector<T>> {
  CupertinoBackGestureController<T>? _backGestureController;

  late HorizontalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = HorizontalDragGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();

    // If this is disposed during a drag, call navigator.didStopUserGesture.
    if (_backGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_backGestureController?.navigator.mounted ?? false) {
          _backGestureController?.navigator.didStopUserGesture();
        }
        _backGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted, 'Tried to start a gesture on a disposed CupertinoBackGestureDetector');
    assert(_backGestureController == null, 'Started a gesture before ending the previous one.');
    _backGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted, 'Tried to update a gesture on a disposed CupertinoBackGestureDetector');
    assert(_backGestureController != null, 'Updated a gesture that has not started.');
    _backGestureController!.dragUpdate(_convertToLogical(details.primaryDelta! / context.size!.width));
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted, 'Tried to end a gesture on a disposed CupertinoBackGestureDetector');
    assert(_backGestureController != null, 'Ended a gesture that has not started.');
    _backGestureController!.dragEnd(_convertToLogical(details.velocity.pixelsPerSecond.dx / context.size!.width));
    _backGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted, 'Tried to cancel a gesture on a disposed CupertinoBackGestureDetector');
    // This can be called even if start is not called, paired with the "down" event
    // that we don't consider here.
    _backGestureController?.dragEnd(0);
    _backGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (widget.enabledCallback()) {
      _recognizer.addPointer(event);
    }
  }

  double _convertToLogical(double value) => switch (Directionality.of(context)) {
    TextDirection.rtl => -value,
    TextDirection.ltr => value,
  };

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context), 'Must have a Directionality');
    // For devices with notches, the drag area needs to be larger on the side
    // that has the notch.
    final dragAreaWidth = switch (Directionality.of(context)) {
      TextDirection.rtl => MediaQuery.paddingOf(context).right,
      TextDirection.ltr => MediaQuery.paddingOf(context).left,
    };
    return Stack(
      fit: StackFit.passthrough,
      children: <Widget>[
        widget.child,
        PositionedDirectional(
          start: 0,
          width: max(dragAreaWidth, _kBackGestureWidth),
          top: 0,
          bottom: 0,
          child: Listener(onPointerDown: _handlePointerDown, behavior: HitTestBehavior.translucent),
        ),
      ],
    );
  }
}

/// A controller for an iOS-style back gesture.
///
/// This is created by a [CupertinoPageRoute] in response from a gesture caught
/// by a [CupertinoBackGestureDetector] widget, which then also feeds it input
/// from the gesture. It controls the animation controller owned by the route,
/// based on the input provided by the gesture detector.
///
/// This class works entirely in logical coordinates (0.0 is new page dismissed,
/// 1.0 is new page on top).
///
/// The type `T` specifies the return type of the route with which this gesture
/// detector controller is associated.
class CupertinoBackGestureController<T> {
  /// Creates a controller for an iOS-style back gesture.
  CupertinoBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  /// The animation controller.
  final AnimationController controller;

  /// The navigator state.
  final NavigatorState navigator;

  /// The callback function that will be called to check if the route is active.
  final ValueGetter<bool> getIsActive;

  /// The callback function that will be called to check if the route is current.
  final ValueGetter<bool> getIsCurrent;

  /// The drag gesture has changed by [delta]. The total range of the drag
  /// should be 0.0 to 1.0.
  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  /// The drag gesture has ended with a horizontal motion of [velocity] as a
  /// fraction of screen width per second.
  void dragEnd(double velocity) {
    // Fling in the appropriate direction.
    //
    // This curve has been determined through rigorously eyeballing native iOS
    // animations.
    const Curve animationCurve = Curves.fastEaseInToSlowEaseOut;
    final isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      // If the page has already been navigated away from, then the animation
      // direction depends on whether or not it's still in the navigation stack,
      // regardless of velocity or drag position. For example, if a route is
      // being slowly dragged back by just a few pixels, but then a programmatic
      // pop occurs, the route should still be animated off the screen.
      // See https://github.com/flutter/flutter/issues/141268.
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      // If the user releases the page before mid screen with sufficient velocity,
      // or after mid screen, we should animate the page out. Otherwise, the page
      // should be animated back in.
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(1, duration: _kDroppedSwipePageAnimationDuration, curve: animationCurve);
    } else {
      if (isCurrent) {
        // This route is destined to pop at this point. Reuse navigator's pop.
        navigator.pop();
      }

      // The popping may have finished inline if already at the target destination.
      if (controller.isAnimating) {
        controller.animateBack(0, duration: _kDroppedSwipePageAnimationDuration, curve: animationCurve);
      }
    }

    if (controller.isAnimating) {
      // Keep the userGestureInProgress in true state so we don't change the
      // curve of the page transition mid-flight since CupertinoPageTransition
      // depends on userGestureInProgress.
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}

const double _kBackGestureWidth = 20;
const double _kMinFlingVelocity = 1; // Screen widths per second.

// The duration for a page to animate when the user releases it mid-swipe.
const Duration _kDroppedSwipePageAnimationDuration = Duration(milliseconds: 350);
