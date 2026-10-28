import 'package:elixir/elixir.dart';
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

/// Collects the errors reported to [FlutterError] until the end of a plain `test`.
List<FlutterErrorDetails> captureErrors() {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  addTearDown(() => FlutterError.onError = previous);
  return errors;
}
