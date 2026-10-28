import 'dart:async';

import 'package:elixir/elixir.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const a = TestPage(Alias.a);
const b = TestPage(Alias.b);
const c = TestPage(Alias.c);
const d = TestPage(Alias.d);
const e = TestPage(Alias.e);

/// An outer Elixir whose `scope` page hosts an inner one.
Future<(ElixirController, ElixirController)> _pumpNested(
  WidgetTester tester, {
  List<ElixirPage> outerTail = const [],
  List<ElixirGuard> innerGuards = const [],
}) async {
  final inner = controllerOf([b, c], guards: innerGuards);
  final outer = controllerOf([a, TestPage(Alias.scope, child: Elixir(controller: inner)), ...outerTail]);
  await pumpApp(tester, Elixir(controller: outer));
  return (outer, inner);
}

/// Pumps [child] under a listener recording every back button report.
Future<List<bool>> _pumpReporting(WidgetTester tester, Widget child) async {
  final reports = <bool>[];
  await pumpApp(
    tester,
    NotificationListener<NavigationNotification>(
      onNotification: (notification) {
        reports.add(notification.canHandlePop);
        return false;
      },
      child: child,
    ),
  );
  return reports;
}

void main() {
  group('back button', () {
    testWidgets('goes to the inner Elixir first, then to the outer one', (tester) async {
      final (outer, inner) = await _pumpNested(tester);

      expect(await back(tester), isTrue);
      expect(aliases(inner), [Alias.b]);

      expect(await back(tester), isTrue, reason: 'the inner Elixir has a single page: the outer one pops');
      expect(aliases(outer), [Alias.a]);

      expect(await back(tester), isFalse, reason: 'W5: the root page lets the platform close the app');
    });

    testWidgets('skips an inner Elixir under a covered route', (tester) async {
      final (outer, inner) = await _pumpNested(tester, outerTail: const [d]);

      expect(await back(tester), isTrue);
      expect(aliases(outer), [Alias.a, Alias.scope]);
      expect(aliases(inner), [Alias.b, Alias.c]);
    });

    testWidgets('W4: closes a dialog opened imperatively, not the page below it', (tester) async {
      final controller = controllerOf([a, b]);
      await pumpApp(tester, Elixir(controller: controller));
      unawaited(showDialog<void>(context: tester.element(find.text('b')), builder: (_) => const Text('dialog')));
      await tester.pumpAndSettle();

      expect(await back(tester), isTrue);
      expect(find.text('dialog'), findsNothing);
      expect(aliases(controller), [Alias.a, Alias.b]);
    });

    testWidgets('W4: respects PopScope', (tester) async {
      final controller = controllerOf([a, const TestPage(Alias.b, child: PopScope(canPop: false, child: Text('b')))]);
      await pumpApp(tester, Elixir(controller: controller));

      expect(await back(tester), isTrue);
      expect(aliases(controller), [Alias.a, Alias.b]);
    });

    testWidgets('onBackButtonPressed replaces the default', (tester) async {
      final controller = controllerOf([a, b, c]);
      NavigatorState? received;
      await pumpApp(
        tester,
        Elixir(
          controller: controller,
          onBackButtonPressed: (navigator) async {
            received = navigator;
            controller.popUntil(Alias.a);
            return true;
          },
        ),
      );

      expect(await back(tester), isTrue);
      expect(aliases(controller), [Alias.a]);
      expect(received, isNotNull);
    });

    testWidgets('W8: of two visible nested Elixirs the newest gets the back press first', (tester) async {
      final left = controllerOf([b, c]);
      final right = controllerOf([d, e]);
      final outer = controllerOf([
        TestPage(
          Alias.scope,
          child: Row(
            children: [
              Expanded(child: Elixir(controller: left)),
              Expanded(child: Elixir(controller: right)),
            ],
          ),
        ),
      ]);
      await pumpApp(tester, Elixir(controller: outer));

      expect(await back(tester), isTrue);
      expect(aliases(right), [Alias.d]);
      expect(aliases(left), [Alias.b, Alias.c]);
    });

    testWidgets('W6: the root reports for the whole tree', (tester) async {
      final inner = controllerOf([b, c]);
      final outer = controllerOf([TestPage(Alias.scope, child: Elixir(controller: inner))]);
      final reports = await _pumpReporting(tester, Elixir(controller: outer));
      expect(reports.last, isTrue, reason: 'the outer navigator cannot pop, the inner one can');

      // The outer navigator reports `false` for itself after this pop: the inner one must not be overwritten.
      outer.push(d);
      await tester.pumpAndSettle();
      outer.pop();
      await tester.pumpAndSettle();
      expect(reports.last, isTrue);

      inner.pop();
      await tester.pumpAndSettle();
      expect(reports.last, isFalse);
    });

    testWidgets('W6: a hidden Elixir does not claim the back button', (tester) async {
      final visible = controllerOf([a]);
      final hidden = controllerOf([b, c]);
      final reports = await _pumpReporting(
        tester,
        IndexedStack(
          // Sibling navigators cannot share the HeroController of the app.
          children: [
            HeroControllerScope.none(child: Elixir(controller: visible)),
            HeroControllerScope.none(child: Elixir(controller: hidden)),
          ],
        ),
      );

      expect(reports.last, isFalse);
      expect(await back(tester), isFalse);
      expect(aliases(hidden), [Alias.b, Alias.c]);
    });
  });

  group('state', () {
    testWidgets('W7: transitions of the outer navigator do not re-run the inner guards', (tester) async {
      var runs = 0;
      final (outer, _) = await _pumpNested(
        tester,
        innerGuards: [
          ElixirGuard((from, to) {
            runs++;
            return to;
          }),
        ],
      );
      final before = runs;

      outer.push(d);
      await tester.pumpAndSettle();
      outer.pop();
      await tester.pumpAndSettle();

      expect(runs, before);
    });

    testWidgets('W9: a push from the initState of a page notifies after the frame', (tester) async {
      final controller = controllerOf([const TestPage(Alias.a, child: _PushOnInit(b))]);
      var builds = 0;
      await pumpApp(
        tester,
        StatefulBuilder(
          builder: (context, setState) {
            builds++;
            return NotificationListener<ElixirNotification>(
              // A listener rebuilding an ancestor of the Elixir.
              onNotification: (_) {
                setState(() {});
                return false;
              },
              child: Elixir(controller: controller),
            );
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(aliases(controller), [Alias.a, Alias.b]);
      expect(find.text('b'), findsOneWidget);
      expect(builds, 2);
    });

    testWidgets('W12: a page closed by the user and kept by a guard is shown again', (tester) async {
      final controller = controllerOf([a, b], guards: [ElixirGuard((from, to) => from.isEmpty ? to : from)]);
      await pumpApp(tester, Elixir(controller: controller));

      Navigator.of(tester.element(find.text('b'))).pop();
      await tester.pumpAndSettle();

      expect(aliases(controller), [Alias.a, Alias.b]);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('W13: Elixir.stackOf rebuilds on every change', (tester) async {
      final seen = <int>[];
      final controller = controllerOf([
        TestPage(
          Alias.a,
          child: Builder(
            builder: (context) {
              seen.add(Elixir.stackOf(context).length);
              return const SizedBox();
            },
          ),
        ),
      ]);
      await pumpApp(tester, Elixir(controller: controller));

      controller.push(b);
      await tester.pumpAndSettle();

      expect(seen.first, 1);
      expect(seen.last, 2);
    });

    testWidgets('W19: Navigator.pop(context, result) completes pushForResult', (tester) async {
      final controller = controllerOf([a]);
      await pumpApp(tester, Elixir(controller: controller));
      final result = controller.pushForResult<String>(b);
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.text('b'))).pop('done');
      await tester.pumpAndSettle();

      expect(await result, 'done');
      expect(aliases(controller), [Alias.a]);
    });

    testWidgets('context.elixir is the controller of the closest Elixir', (tester) async {
      final (outer, inner) = await _pumpNested(tester);

      expect(tester.element(find.text('a', skipOffstage: false)).elixir, same(outer));
      expect(tester.element(find.text('c')).elixir, same(inner));
    });
  });

  group('W24: notifications', () {
    testWidgets('bubble from the nested Elixirs to a listener above the root', (tester) async {
      final seen = <String>[];
      final inner = controllerOf([b, c], name: Alias.scope);
      final outer = controllerOf([a, TestPage(Alias.scope, child: Elixir(controller: inner))], name: Alias.a);
      await pumpApp(
        tester,
        NotificationListener<ElixirNotification>(
          onNotification: (n) {
            seen.add('${n.controller.name?.alias}: +${n.added.join(',')} -${n.removed.join(',')}');
            return false;
          },
          child: Elixir(controller: outer),
        ),
      );

      inner.pop();
      await tester.pumpAndSettle();
      outer.push(d);
      await tester.pumpAndSettle();

      expect(seen, ['scope: + -c', 'a: +d -']);
    });

    testWidgets('a throwing NotificationListener is reported and the change is still shown', (tester) async {
      final controller = controllerOf([a]);
      await pumpApp(
        tester,
        NotificationListener<ElixirNotification>(
          onNotification: (_) => throw StateError('broken'),
          child: Elixir(controller: controller),
        ),
      );

      controller.push(b);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>());
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('Elixir.listener hears its own Elixir and the nested ones', (tester) async {
      String describe(ElixirNotification n) => '${n.controller.name?.alias}: ${n.next.join(' > ')}';
      final outerSeen = <String>[];
      final innerSeen = <String>[];
      final inner = controllerOf([b, c], name: Alias.scope);
      final outer = controllerOf([
        a,
        TestPage(
          Alias.scope,
          child: Elixir(controller: inner, listener: (n) => innerSeen.add(describe(n))),
        ),
      ], name: Alias.a);
      await pumpApp(tester, Elixir(controller: outer, listener: (n) => outerSeen.add(describe(n))));

      inner.pop();
      await tester.pumpAndSettle();
      outer.push(d);
      await tester.pumpAndSettle();

      expect(outerSeen, ['scope: b', 'a: a > scope > d']);
      expect(innerSeen, ['scope: b']);
    });

    testWidgets('a throwing Elixir.listener is reported and the change still bubbles up', (tester) async {
      final seen = <String>[];
      final inner = controllerOf([b, c], name: Alias.scope);
      final outer = controllerOf([a, TestPage(Alias.scope, child: Elixir(controller: inner))]);
      await pumpApp(
        tester,
        NotificationListener<ElixirNotification>(
          onNotification: (n) {
            seen.add('${n.controller.name?.alias}');
            return false;
          },
          child: Elixir(controller: outer, listener: (_) => throw StateError('broken')),
        ),
      );

      inner.pop();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isA<StateError>());
      expect(seen, ['scope'], reason: 'the notification passed the throwing listener of the outer Elixir');
    });
  });
}

class _PushOnInit extends StatefulWidget {
  const _PushOnInit(this.page);

  final ElixirPage page;

  @override
  State<_PushOnInit> createState() => _PushOnInitState();
}

class _PushOnInitState extends State<_PushOnInit> {
  @override
  void initState() {
    super.initState();
    context.elixir.push(widget.page);
  }

  @override
  Widget build(BuildContext context) => const Text('a');
}
