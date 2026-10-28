import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const a = TestPage(Alias.a);
const dialog = DialogTestPage(Alias.dialog, child: Text('dialog'));
const sheet = SheetTestPage(
  Alias.sheet,
  child: SizedBox(height: 300, width: double.infinity, child: Text('sheet')),
);

Future<ElixirController> _pump(WidgetTester tester) async {
  final controller = controllerOf([a], guards: [const ModalGuard()]);
  await pumpApp(tester, Elixir(controller: controller));
  return controller;
}

void main() {
  testWidgets('a dialog page returns its result to pushForResult', (tester) async {
    final controller = await _pump(tester);
    final result = controller.pushForResult<bool>(dialog);
    await tester.pumpAndSettle();
    expect(find.text('a'), findsOneWidget, reason: 'the page below stays visible');

    Navigator.of(tester.element(find.text('dialog'))).pop(true);
    await tester.pumpAndSettle();

    expect(await result, isTrue);
    expect(aliases(controller), [Alias.a]);
  });

  testWidgets('a tap on the barrier closes the dialog with null', (tester) async {
    final controller = await _pump(tester);
    final result = controller.pushForResult<bool>(dialog);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('dialog'), findsNothing);
    expect(await result, isNull);
    expect(aliases(controller), [Alias.a]);
  });

  testWidgets('the back button closes the dialog first', (tester) async {
    final controller = await _pump(tester);
    controller.push(dialog);
    await tester.pumpAndSettle();

    expect(await back(tester), isTrue);
    expect(aliases(controller), [Alias.a]);
  });

  testWidgets('a downward drag closes a sheet page', (tester) async {
    final controller = await _pump(tester);
    final result = controller.pushForResult<bool>(sheet);
    await tester.pumpAndSettle();

    await tester.drag(find.text('sheet'), const Offset(0, 250));
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
    expect(aliases(controller), [Alias.a]);
    expect(await result, isNull);
  });

  testWidgets('a short slow drag lets the sheet settle back', (tester) async {
    final controller = await _pump(tester);
    controller.push(sheet);
    await tester.pumpAndSettle();

    await tester.timedDrag(find.text('sheet'), const Offset(0, 60), const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsOneWidget);
    expect(aliases(controller), [Alias.a, Alias.sheet]);
  });

  testWidgets('a screen pushed over a dialog goes under it', (tester) async {
    final controller = await _pump(tester);
    controller
      ..push(dialog)
      ..push(const TestPage(Alias.b));
    await tester.pumpAndSettle();

    expect(aliases(controller), [Alias.a, Alias.b, Alias.dialog]);
    expect(find.text('dialog'), findsOneWidget);
  });
}
