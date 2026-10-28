import 'package:elixir/elixir.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

const a = TestPage(Alias.a);
const b = TestPage(Alias.b);
const c = TestPage(Alias.c);
const d = TestPage(Alias.d);

List<Alias> names(ElixirNavigationState state) => [for (final page in state) page.alias as Alias];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pipeline', () {
    test('W1: listeners see only the guarded state, once per change', () {
      final controller = controllerOf(
        [a],
        guards: [
          ElixirGuard(
            (from, to) => to.any((page) => page.alias == Alias.b) ? [...to.where((p) => p.alias != Alias.b), c] : to,
          ),
        ],
      );
      final seen = <List<Alias>>[];
      controller
        ..addListener(() => seen.add(aliases(controller)))
        ..push(b);

      expect(seen, [
        [Alias.a, Alias.c],
      ]);
    });

    test('W2: the initial state is validated without any widget', () {
      expect(aliases(controllerOf([b], guards: [const RootGuard(a)])), [Alias.a, Alias.b]);
      expect(() => ElixirController([]), throwsArgumentError);
      expect(() => ElixirController([a], guards: [ElixirGuard((from, to) => [])]), throwsArgumentError);
    });

    test('W3: a guard gets the committed state and the requested one', () {
      final calls = <String>[];
      final controller = controllerOf(
        [a],
        guards: [
          ElixirGuard((from, to) {
            calls.add('${names(from)} -> ${names(to)}');
            return to;
          }),
        ],
      )..push(b);

      expect(calls, ['[] -> [Alias.a]', '[Alias.a] -> [Alias.a, Alias.b]']);
      expect('${controller.guards.single}', 'ElixirGuard()');
    });

    test('W3: a guard returning `from` cancels the change', () {
      final controller = controllerOf([a], guards: [ElixirGuard((from, to) => to.length > 2 ? from : to)])
        ..push(b)
        ..push(c);

      expect(aliases(controller), [Alias.a, Alias.b]);
    });

    test('W10: a change from a listener is applied after the current one', () {
      final controller = controllerOf([a]);
      final seen = <List<Alias>>[];
      controller
        ..addListener(() {
          seen.add(aliases(controller));
          if (controller.state.last.alias == Alias.b) controller.push(c);
        })
        ..push(b);

      expect(seen, [
        [Alias.a, Alias.b],
        [Alias.a, Alias.b, Alias.c],
      ]);
    });

    test('W10: a listener changing the state on every change is stopped', () {
      final errors = captureErrors();
      final controller = controllerOf([a]);
      var i = 0;
      controller
        ..addListener(() => controller.push(TestPage(Alias.b, arguments: {'i': i++})))
        ..push(c);

      expect(errors.single.exception, isA<StateError>());
      expect(controller.state.length, lessThan(70));
    });

    test('W11: a throwing guard is reported and skipped', () {
      final errors = captureErrors();
      final controller = controllerOf(
        [a],
        guards: [ElixirGuard((from, to) => throw StateError('broken')), const RootGuard(a)],
      )..change((_) => [b]);

      expect(aliases(controller), [Alias.a, Alias.b]);
      expect(errors, hasLength(2), reason: 'the initial state and the change');
    });

    test('W11: a throwing change is reported and keeps the state', () {
      final errors = captureErrors();
      final controller = controllerOf([a])..change((_) => throw StateError('broken'));

      expect(aliases(controller), [Alias.a]);
      expect(errors, hasLength(1));
    });

    test('an empty state is reported and rejected', () {
      final errors = captureErrors();
      final controller = controllerOf([a, b])..change((_) => []);

      expect(aliases(controller), [Alias.a, Alias.b]);
      expect(errors.single.exception, isA<StateError>());
    });

    test('W15: a new instance with the same key is committed', () {
      final controller = controllerOf([a, const TestPage(Alias.b, child: SizedBox())]);
      const page = TestPage(Alias.b, child: SizedBox(width: 1));
      controller.change((state) => [state.first, page]);

      expect(controller.state.last, same(page));
    });

    test('W18: pushing an existing key moves the page to the top', () {
      final controller = controllerOf([a, b, c])..push(b);

      expect(aliases(controller), [Alias.a, Alias.c, Alias.b]);
    });

    test('the revalidate listenable re-runs the guards', () {
      final signedIn = ValueNotifier(false);
      addTearDown(signedIn.dispose);
      final controller = controllerOf(
        [a],
        guards: [
          ElixirGuard(
            (from, to) => switch ((signedIn.value, names(to))) {
              (false, _) => [const TestPage(Alias.login)],
              (true, [Alias.login]) => [a],
              _ => to,
            },
          ),
        ],
        revalidate: signedIn,
      );
      expect(aliases(controller), [Alias.login]);

      signedIn.value = true;
      expect(aliases(controller), [Alias.a]);
    });
  });

  group('guards', () {
    test('RootGuard keeps the root at the bottom', () {
      final controller = controllerOf([b], guards: [const RootGuard(a)])..change((_) => [c, a]);
      expect(aliases(controller), [Alias.a, Alias.c]);

      controller.change((_) => []);
      expect(aliases(controller), [Alias.a]);
    });

    test('ModalGuard keeps the modal pages on top, in their order', () {
      final controller = controllerOf([a], guards: [const ModalGuard()])
        ..push(const DialogTestPage(Alias.dialog))
        ..push(const SheetTestPage(Alias.sheet))
        ..push(b);
      expect(aliases(controller), [Alias.a, Alias.b, Alias.dialog, Alias.sheet]);

      controller.removeTag(ElixirPage.modalTag);
      expect(aliases(controller), [Alias.a, Alias.b]);
    });
  });

  group('methods', () {
    test('pop keeps the last page', () {
      final controller = controllerOf([a, b])
        ..pop()
        ..pop();

      expect(aliases(controller), [Alias.a]);
    });

    test('W21: reset returns to the initial state, validated again', () {
      var dropB = false;
      final controller = controllerOf(
        [a, b],
        guards: [ElixirGuard((from, to) => dropB ? to.where((page) => page.alias != Alias.b).toList() : to)],
      )..push(c);
      dropB = true;
      controller.reset();

      expect(aliases(controller), [Alias.a]);
    });

    test('W22: popUntil pops to the topmost page with the alias', () {
      final controller = controllerOf([
        a,
        const TestPage(Alias.b, arguments: {'id': 1}),
        c,
        const TestPage(Alias.b, arguments: {'id': 2}),
        d,
      ])..popUntil(Alias.b);
      expect(controller.state.map((page) => '$page'), ['a', 'b?id=1', 'c', 'b?id=2']);

      controller.popUntil(Alias.e);
      expect(controller.state, hasLength(4), reason: 'no page with the alias: nothing changes');
    });
  });

  group('W19: results', () {
    test('pop completes pushForResult with its result', () async {
      final controller = controllerOf([a]);
      final result = controller.pushForResult<bool>(b);
      controller.pop(true);

      expect(await result, isTrue);
    });

    test('remove completes pushForResult with its result', () async {
      final controller = controllerOf([a]);
      final result = controller.pushForResult<String>(b);
      controller.remove(b, 'done');

      expect(await result, 'done');
    });

    test('a result of another type completes with null', () async {
      final controller = controllerOf([a]);
      final result = controller.pushForResult<int>(b);
      controller.pop('text');

      expect(await result, isNull);
    });

    test('a page removed without a result completes with null', () async {
      final controller = controllerOf([a]);
      final result = controller.pushForResult<bool>(b);
      controller.change((_) => [a]);

      expect(await result, isNull);
    });

    test('a push rejected by a guard completes with null', () async {
      final controller = controllerOf([a], guards: [ElixirGuard((from, to) => to.length > 1 ? from : to)]);

      expect(await controller.pushForResult<bool>(b), isNull);
    });

    test('a pop cancelled by a guard drops its result', () async {
      var locked = true;
      final controller = controllerOf([a], guards: [ElixirGuard((from, to) => locked && from.length > 1 ? from : to)]);
      final result = controller.pushForResult<bool>(b);
      controller.pop(true);
      expect(aliases(controller), [Alias.a, Alias.b]);

      locked = false;
      controller.pop();
      expect(await result, isNull);
    });

    test('pushing for a result again completes the previous future with null', () async {
      final controller = controllerOf([a]);
      final first = controller.pushForResult<bool>(b);
      final second = controller.pushForResult<bool>(b);
      controller.pop(true);

      expect(await first, isNull);
      expect(await second, isTrue);
    });

    test('a push for a result from a listener waits for its turn in the queue', () async {
      final controller = controllerOf([a]);
      Future<bool?>? result;
      controller
        ..addListener(() {
          if (controller.state.last.alias != Alias.b) return;
          controller.push(c);
          result = controller.pushForResult<bool>(d);
        })
        ..push(b);
      expect(aliases(controller), [Alias.a, Alias.b, Alias.c, Alias.d]);

      controller.pop(true);
      expect(await result, isTrue);
    });

    test('dispose completes with null', () async {
      final controller = controllerOf([a]);
      final result = controller.pushForResult<bool>(b);
      controller.dispose();

      expect(await result, isNull);
    });
  });
}
