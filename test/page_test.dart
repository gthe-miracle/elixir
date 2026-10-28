import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  test('W17: the default key is built from the name and the arguments', () {
    expect(const TestPage(Alias.a).key, const ValueKey('a'));
    expect(const TestPage(Alias.a, arguments: {'id': 1, 'q': null}).key, const ValueKey('a?id=1&q'));
    final id = DateTime(2025).year; // a runtime value: two distinct instances
    expect(TestPage(Alias.a, arguments: {'id': id}).key, TestPage(Alias.a, arguments: {'id': id}).key);
    expect(const TestPage(Alias.a, arguments: {'id': 1}).key, isNot(const TestPage(Alias.a, arguments: {'id': 2}).key));
    expect(
      const TestPage(Alias.a, arguments: {'x': 'a&b=c'}).key,
      isNot(const TestPage(Alias.a, arguments: {'x': 'a', 'b': 'c'}).key),
      reason: 'a separator inside a value is escaped',
    );
    expect(const TestPage(Alias.a, arguments: {'x': '%26'}).key, const ValueKey('a?x=%2526'));
    expect(const TestPage(Alias.a, key: ValueKey('own')).key, const ValueKey('own'));
  });

  test('W15, W20: pages compare by identity, the name comes from the alias, tags and arguments are optional', () {
    final id = DateTime(2025).year; // a runtime value: two distinct instances
    final first = TestPage(Alias.a, arguments: {'id': id});
    final second = TestPage(Alias.a, arguments: {'id': id});

    expect(first == second, isFalse);
    expect(first.key, second.key);
    expect(first.name, 'a');
    expect('$first', 'a?id=2025');
    expect(const TestPage(Alias.a).arguments, isEmpty);
    expect(const TestPage(Alias.a).tags, isEmpty);
  });

  testWidgets('W16: a page replaced under the same key updates the screen and keeps the route', (tester) async {
    final controller = controllerOf([const TestPage(Alias.a), const TestPage(Alias.b, child: Text('old'))]);
    await pumpApp(tester, Elixir(controller: controller));
    final route = ModalRoute.of(tester.element(find.text('old')));

    controller.change((state) => [state.first, const TestPage(Alias.b, child: Text('new'))]);
    await tester.pumpAndSettle();

    expect(find.text('new'), findsOneWidget);
    expect(ModalRoute.of(tester.element(find.text('new'))), same(route), reason: 'the route and its state are kept');
  });
}
