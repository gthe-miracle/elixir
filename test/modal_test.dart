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

  testWidgets('a list inside a sheet takes the drag and leaves the sheet alone', (tester) async {
    final controller = await _pump(tester);
    controller.push(
      SheetTestPage(
        Alias.sheet,
        child: SizedBox(height: 300, child: ListView(children: [for (var i = 0; i < 40; i++) Text('item $i')])),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(aliases(controller), [Alias.a, Alias.sheet]);
  });

  testWidgets('a button inside a sheet takes the tap and leaves the sheet alone', (tester) async {
    final controller = await _pump(tester);
    var tapped = false;
    controller.push(
      SheetTestPage(
        Alias.sheet,
        child: GestureDetector(
          onTap: () => tapped = true,
          child: const SizedBox(height: 300, width: double.infinity, child: Text('sheet')),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('sheet'));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
    expect(aliases(controller), [Alias.a, Alias.sheet]);
  });

  testWidgets('a drag ends the user gesture of a sheet closed under the finger', (tester) async {
    final controller = await _pump(tester);
    controller.push(sheet);
    await tester.pumpAndSettle();
    final navigator = Navigator.of(tester.element(find.text('sheet')));

    final gesture = await tester.startGesture(tester.getCenter(find.text('sheet')));
    await gesture.moveBy(const Offset(0, 40));
    await tester.pump();
    expect(navigator.userGestureInProgress, isTrue);

    controller.pop();
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(navigator.userGestureInProgress, isFalse);
    expect(aliases(controller), [Alias.a]);
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
