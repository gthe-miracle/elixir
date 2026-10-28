import 'package:example/src/common/widget/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<bool> _back(WidgetTester tester) async {
  final handled = await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  return handled;
}

void main() {
  testWidgets('settings scope, dialog result, sheet, then back all the way', (tester) async {
    await tester.pumpWidget(const App());
    await tester.pumpAndSettle();
    expect(find.text('Pages: home'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('data: Data from home'), findsOneWidget);

    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Dialog result: true'), findsOneWidget);

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    expect(find.text('About'), findsOneWidget);

    expect(await _back(tester), isTrue, reason: 'closes the sheet');
    expect(find.text('About'), findsNothing);

    expect(await _back(tester), isTrue, reason: 'leaves the settings scope');
    expect(find.text('Pages: home'), findsOneWidget);

    expect(await _back(tester), isFalse, reason: 'the root page lets the platform close the app');
  });
}
