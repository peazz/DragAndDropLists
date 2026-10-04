import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _viewportKey = ValueKey('viewport');
const _headerKey = ValueKey('pinned-header');

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.extent);
  final double extent;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent * 2;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const ColoredBox(key: _headerKey, color: Colors.blue,
        child: SizedBox.expand(child: Text('Pinned header')));
  }
  @override
  bool shouldRebuild(covariant _Header oldDelegate) => extent != oldDelegate.extent;
}

Future<void> _mount(WidgetTester tester, ScrollController controller,
    {bool shrinkWrap = true, double headerExtent = 80, ValueNotifier<bool>? disabled,
    OnItemReorder? onItemReorder}) async {
  final lists = List.generate(6, (list) => DragAndDropList(
    canDrag: false,
    header: SizedBox(height: 36, child: Text('List $list')),
    children: List.generate(8, (item) => DragAndDropItem(
      child: Container(key: ValueKey('item-$list-$item'), height: 50,
        color: Colors.white, alignment: Alignment.center,
        child: Text('$list.$item')),
    )),
  ));

  Widget content(bool disableScrolling) => MaterialApp(home: Scaffold(
    body: Padding(padding: const EdgeInsets.only(top: 70, bottom: 80),
      child: CustomScrollView(key: _viewportKey, controller: controller,
        shrinkWrap: shrinkWrap, physics: const ClampingScrollPhysics(),
        slivers: [
          if (headerExtent > 0)
            SliverPersistentHeader(pinned: true, delegate: _Header(headerExtent)),
          SliverSafeArea(top: false, sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            sliver: DragAndDropLists(
              sliverList: true, scrollController: controller, children: lists,
              autoScrollExtent: 72, autoScrollSpeed: 720,
              listDecoration: const BoxDecoration(),
              disableScrolling: disableScrolling,
              lastListTargetSize: 0, lastItemTargetHeight: 0,
              onItemReorder: onItemReorder ?? (_, __, ___, ____) {},
              onListReorder: (_, __) {},
            ),
          )),
        ],
      ),
    ),
  ));
  await tester.pumpWidget(disabled == null ? content(false) :
    ValueListenableBuilder<bool>(valueListenable: disabled,
      builder: (_, value, __) => content(value)));
  await tester.pumpAndSettle();
}

Finder _visibleItem(WidgetTester tester, {int? excludeList}) {
  final viewport = tester.getRect(find.byKey(_viewportKey));
  final header = find.byKey(_headerKey);
  final top = header.evaluate().isEmpty ? viewport.top : tester.getRect(header).bottom;
  for (var list = 0; list < 6; list++) {
    if (list == excludeList) continue;
    for (var item = 0; item < 8; item++) {
      final finder = find.byKey(ValueKey('item-$list-$item'));
      if (finder.evaluate().length != 1) continue;
      final rect = tester.getRect(finder);
      if (rect.top > top + 30 && rect.bottom < viewport.bottom - 40 &&
          rect.left >= viewport.left && rect.right <= viewport.right) {
        return finder;
      }
    }
  }
  throw StateError('No visible draggable item');
}

Future<TestGesture> _drag(WidgetTester tester) async {
  final gesture = await tester.startGesture(tester.getCenter(_visibleItem(tester)));
  await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
  return gesture;
}

Future<void> _hold(WidgetTester tester, [int frames = 60]) async {
  for (var frame = 0; frame < frames; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final headerExtent in [0.0, 48.0, 120.0]) {
    testWidgets('uses layout bounds with header extent $headerExtent', (tester) async {
      final controller = ScrollController(initialScrollOffset: 900);
      addTearDown(controller.dispose);
      await _mount(tester, controller, headerExtent: headerExtent);
      final gesture = await _drag(tester);
      final viewport = tester.getRect(find.byKey(_viewportKey));
      final top = headerExtent == 0 ? viewport.top : tester.getRect(find.byKey(_headerKey)).bottom;
      await gesture.moveTo(Offset(viewport.center.dx, top + 8));
      final before = controller.offset;
      await _hold(tester);
      expect(before - controller.offset, greaterThan(450));
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  for (final shrinkWrap in [true, false]) {
    testWidgets('scrolls up below a pinned header (shrinkWrap: $shrinkWrap)', (tester) async {
      final controller = ScrollController(initialScrollOffset: 900);
      addTearDown(controller.dispose);
      await _mount(tester, controller, shrinkWrap: shrinkWrap);
      final gesture = await _drag(tester);
      final header = tester.getRect(find.byKey(_headerKey));
      await gesture.moveTo(Offset(header.center.dx, header.bottom + 8));
      final before = controller.offset;
      await _hold(tester);
      expect(before - controller.offset, greaterThan(450));
      expect(tester.getRect(find.byKey(_headerKey)).top, 70);
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  for (final direction in [TextDirection.ltr, TextDirection.rtl]) {
    testWidgets('horizontal scrolling respects $direction', (tester) async {
      final controller = ScrollController(initialScrollOffset: 300);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(home: Directionality(
        textDirection: direction,
        child: Scaffold(body: Padding(
          padding: const EdgeInsets.fromLTRB(90, 70, 60, 80),
          child: DragAndDropLists(
            key: _viewportKey, axis: Axis.horizontal, listWidth: 240,
            listPadding: EdgeInsets.zero,
            scrollController: controller,
            autoScrollExtent: 72, autoScrollSpeed: 720,
            listDecoration: const BoxDecoration(),
            lastListTargetSize: 0,
            children: List.generate(6, (list) => DragAndDropList(
              canDrag: false,
              header: const SizedBox(height: 36),
              children: List.generate(4, (item) => DragAndDropItem(
                child: Container(key: ValueKey('item-$list-$item'), height: 50,
                  color: Colors.white, child: Text('$list.$item')),
              )),
            )),
            onItemReorder: (_, __, ___, ____) {}, onListReorder: (_, __) {},
          ),
        )),
      )));
      await tester.pumpAndSettle();
      final gesture = await _drag(tester);
      final viewport = tester.getRect(find.byKey(_viewportKey));
      final forward = direction == TextDirection.ltr ? viewport.right - 8 : viewport.left + 8;
      await gesture.moveTo(Offset(forward, viewport.center.dy));
      final before = controller.offset;
      await _hold(tester, 30);
      expect(controller.offset - before, greaterThan(200));
      final after = controller.offset;
      final backward = direction == TextDirection.ltr ? viewport.left + 8 : viewport.right - 8;
      await gesture.moveTo(Offset(backward, viewport.center.dy));
      await _hold(tester, 30);
      expect(after - controller.offset, greaterThan(200));
      await gesture.up();
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('scrolls down quickly, stops in the middle and reverses direction', (tester) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    final gesture = await _drag(tester);
    final viewport = tester.getRect(find.byKey(_viewportKey));
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    final before = controller.offset;
    await _hold(tester);
    expect(controller.offset - before, greaterThan(450));

    await gesture.moveTo(viewport.center);
    await _hold(tester, 15);
    final stopped = controller.offset;
    await _hold(tester, 15);
    expect(controller.offset, stopped);

    final header = tester.getRect(find.byKey(_headerKey));
    await gesture.moveTo(Offset(header.center.dx, header.bottom + 8));
    await _hold(tester);
    expect(stopped - controller.offset, greaterThan(450));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  for (final cancel in [false, true]) {
    testWidgets('stops after ${cancel ? 'cancelling' : 'releasing'} the drag', (tester) async {
      final controller = ScrollController(initialScrollOffset: 500);
      addTearDown(controller.dispose);
      await _mount(tester, controller);
      final gesture = await _drag(tester);
      final viewport = tester.getRect(find.byKey(_viewportKey));
      await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
      await _hold(tester, 15);
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      await _hold(tester, 15);
      final stopped = controller.offset;
      await _hold(tester, 15);
      expect(controller.offset, stopped);
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('clamps at both scroll limits', (tester) async {
    final controller = ScrollController(initialScrollOffset: 300);
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    final gesture = await _drag(tester);
    final viewport = tester.getRect(find.byKey(_viewportKey));
    await gesture.moveTo(Offset(viewport.center.dx, viewport.top + 5));
    await _hold(tester);
    expect(controller.offset, controller.position.minScrollExtent);

    controller.jumpTo(controller.position.maxScrollExtent - 100);
    await tester.pump();
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 5));
    await _hold(tester);
    expect(controller.offset, controller.position.maxScrollExtent);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('can still drop into another list after auto-scrolling', (tester) async {
    final controller = ScrollController(initialScrollOffset: 180);
    addTearDown(controller.dispose);
    final moves = <List<int>>[];
    await _mount(tester, controller, onItemReorder: (oldItem, oldList, newItem, newList) {
      moves.add([oldList, newList]);
    });
    final gesture = await _drag(tester);
    final viewport = tester.getRect(find.byKey(_viewportKey));
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    await _hold(tester);
    final target = _visibleItem(tester, excludeList: 0);
    await gesture.moveTo(tester.getCenter(target));
    await _hold(tester, 15);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(moves, hasLength(1));
    expect(moves.single.first, 0);
    expect(moves.single.last, isNot(0));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('disabling scrolling stops an active drag', (tester) async {
    final controller = ScrollController(initialScrollOffset: 500);
    final disabled = ValueNotifier(false);
    addTearDown(controller.dispose);
    addTearDown(disabled.dispose);
    await _mount(tester, controller, disabled: disabled);
    final gesture = await _drag(tester);
    final viewport = tester.getRect(find.byKey(_viewportKey));
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    await _hold(tester, 15);
    disabled.value = true;
    await tester.pump();
    final stopped = controller.offset;
    await _hold(tester, 15);
    expect(controller.offset, stopped);
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('disposing during auto-scroll stops its ticker', (tester) async {
    final controller = ScrollController(initialScrollOffset: 500);
    addTearDown(controller.dispose);
    await _mount(tester, controller);
    final gesture = await _drag(tester);
    final viewport = tester.getRect(find.byKey(_viewportKey));
    await gesture.moveTo(Offset(viewport.center.dx, viewport.bottom - 8));
    await _hold(tester, 10);
    await tester.pumpWidget(const SizedBox());
    await gesture.cancel();
    await _hold(tester, 10);
    expect(tester.takeException(), isNull);
  });
}
