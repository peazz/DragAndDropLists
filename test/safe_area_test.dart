import 'package:drag_and_drop_lists/drag_and_drop_lists.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Header extends SliverPersistentHeaderDelegate {
  _Header(this.top);
  final double top;
  @override double get minExtent => top + 36;
  @override double get maxExtent => minExtent + 100;
  @override Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return const ColoredBox(color: Colors.blue, child: SizedBox.expand());
  }
  @override bool shouldRebuild(covariant _Header oldDelegate) => oldDelegate.top != top;
}

Future<void> mount(WidgetTester tester, ScrollController controller,
    {required double safeTop, bool header = true, bool outerSafeArea = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.padding = FakeViewPadding(top: safeTop, bottom: 34);
  tester.view.viewPadding = FakeViewPadding(top: safeTop, bottom: 34);
  addTearDown(tester.view.reset);
  var dragging = false;
  await tester.pumpWidget(MaterialApp(home: Scaffold(
    extendBody: true,
    bottomNavigationBar: const SizedBox(height: 100),
    body: StatefulBuilder(builder: (context, setState) {
      final scrollView = CustomScrollView(
        controller: controller, shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        slivers: [
          if (header) SliverPersistentHeader(pinned: true, delegate: _Header(safeTop)),
          SliverSafeArea(top: !header, sliver: SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            sliver: DragAndDropLists(
              sliverList: true, scrollController: controller,
              autoScrollExtent: 72, autoScrollSpeed: 720,
              lastListTargetSize: 0, lastItemTargetHeight: 0,
              listPadding: const EdgeInsets.symmetric(horizontal: 20),
              onItemDraggingChanged: (_, value) => setState(() => dragging = value),
              onItemReorder: (_, __, ___, ____) {}, onListReorder: (_, __) {},
              children: List.generate(5, (list) => DragAndDropList(
                key: ValueKey('list-$list'), canDrag: false,
                containerBuilder: (child, params) => Padding(
                  padding: EdgeInsets.only(top: list == 0 ? 0 : 15), child: child),
                header: const SizedBox(height: 36),
                lastTarget: SizedBox(height: dragging ? 64 : 0),
                children: List.generate(8, (item) => DragAndDropItem(
                  key: ValueKey('drag-$list-$item'),
                  feedbackWidget: const SizedBox(height: 64, child: Text('Dragging')),
                  child: Container(key: ValueKey('item-$list-$item'), height: 64,
                    color: Colors.white, child: Text('$list.$item')),
                )),
              )),
            ),
          )),
        ],
      );
      return Scaffold(body: outerSafeArea ? SafeArea(child: scrollView) : scrollView);
    }),
  )));
  await tester.pumpAndSettle();
}

Future<TestGesture> start(WidgetTester tester) async {
  for (var list = 0; list < 5; list++) {
    for (var item = 0; item < 8; item++) {
      final finder = find.byKey(ValueKey('item-$list-$item'));
      if (finder.evaluate().isEmpty) continue;
      final rect = tester.getRect(finder);
      if (rect.top > 230 && rect.bottom < 640) {
        final gesture = await tester.startGesture(rect.center);
        await tester.pump(kLongPressTimeout + const Duration(milliseconds: 20));
        return gesture;
      }
    }
  }
  throw StateError('No visible item');
}

Future<void> hold(WidgetTester tester) async {
  for (var frame = 0; frame < 60; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  for (final safeTop in [24.0, 59.0]) {
    for (final header in [false, true]) {
      testWidgets('up with top inset $safeTop, header $header', (tester) async {
        final controller = ScrollController(initialScrollOffset: 1000);
        addTearDown(controller.dispose);
        await mount(tester, controller, safeTop: safeTop, header: header);
        final gesture = await start(tester);
        await gesture.moveTo(Offset(195, safeTop + (header ? 36 : 0) + 24));
        final before = controller.offset;
        await hold(tester);
        expect(before - controller.offset, greaterThan(250));
        await gesture.up();
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('down above the bottom navigation safe area', (tester) async {
    final controller = ScrollController(initialScrollOffset: 1000);
    addTearDown(controller.dispose);
    await mount(tester, controller, safeTop: 59);
    final gesture = await start(tester);
    await gesture.moveTo(const Offset(195, 844 - 100 - 24));
    final before = controller.offset;
    await hold(tester);
    expect(controller.offset - before, greaterThan(250));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('does not count an outer SafeArea twice', (tester) async {
    final controller = ScrollController(initialScrollOffset: 1000);
    addTearDown(controller.dispose);
    await mount(tester, controller, safeTop: 59, header: false, outerSafeArea: true);
    final gesture = await start(tester);
    await gesture.moveTo(const Offset(195, 59 + 56));
    final before = controller.offset;
    await hold(tester);
    expect(before - controller.offset, inExclusiveRange(80, 250));
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });
}
