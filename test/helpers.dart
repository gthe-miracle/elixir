import 'package:elixir/elixir.dart';
import 'package:flutter/cupertino.dart' show CupertinoRouteTransitionMixin;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

enum Alias implements ElixirAlias {
  a,
  b,
  c,
  d,
  e,
  login,
  scope,
  dialog,
  sheet;

  @override
  String get alias => name;
}

/// A page showing its name, unless it is given a child.
base class TestPage extends ElixirPage {
  const TestPage(this.alias, {Widget? child, super.arguments, super.key, this.tags = const <String>{}})
    : super(child: child ?? const _Name());

  @override
  final Alias alias;

  @override
  final Set<String> tags;

  @override
  Route<Object?> createRoute(BuildContext context) => ElixirPageRoute(this);
}

final class DialogTestPage extends TestPage with ElixirDialogPage {
  const DialogTestPage(super.alias, {super.child});
}

final class SheetTestPage extends TestPage with ElixirSheetPage {
  const SheetTestPage(super.alias, {super.child});
}

/// A page with the edge swipe of a Cupertino route.
final class SwipeTestPage extends TestPage {
  const SwipeTestPage(super.alias, {super.child});

  @override
  Route<Object?> createRoute(BuildContext context) => _SwipeRoute(this);
}

final class _SwipeRoute extends PageRoute<Object?> with CupertinoRouteTransitionMixin<Object?> {
  _SwipeRoute(ElixirPage page) : super(settings: page);

  @override
  Widget buildContent(BuildContext context) => (settings as ElixirPage).child;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;
}

class _Name extends StatelessWidget {
  const _Name();

  @override
  Widget build(BuildContext context) => Text((ModalRoute.of(context)!.settings as ElixirPage).name);
}

/// A controller disposed at the end of the test.
ElixirController controllerOf(
  ElixirNavigationState pages, {
  List<ElixirGuard> guards = const <ElixirGuard>[],
  Listenable? revalidate,
  ElixirAlias? name,
}) {
  final controller = ElixirController(pages, guards: guards, revalidate: revalidate, name: name);
  addTearDown(controller.dispose);
  return controller;
}

List<Alias> aliases(ElixirController controller) => [for (final page in controller.state) page.alias as Alias];

Future<void> pumpApp(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(builder: (context, _) => child));
  await tester.pumpAndSettle();
}

/// Presses the system back button; returns whether the app handled it.
Future<bool> back(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

/// Swipes from the left edge of the screen across it.
Future<void> swipeBack(WidgetTester tester) async {
  await tester.dragFrom(const Offset(5, 300), const Offset(600, 0));
  await tester.pumpAndSettle();
}

/// Collects the errors reported to [FlutterError] until the end of a plain `test`.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
