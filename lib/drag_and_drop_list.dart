import 'package:drag_and_drop_lists/drag_and_drop_builder_parameters.dart';
import 'package:drag_and_drop_lists/drag_and_drop_item.dart';
import 'package:drag_and_drop_lists/drag_and_drop_item_target.dart';
import 'package:drag_and_drop_lists/drag_and_drop_item_wrapper.dart';
import 'package:drag_and_drop_lists/drag_and_drop_list_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

/// Builder that receives the default inner content and returns a custom
/// container widget. Use this when [BoxDecoration] alone isn't enough and
/// you need full control over the list wrapper (e.g. a custom card, a
/// [ClipRRect], a [Material], etc.).
typedef ListContainerBuilder = Widget Function(
  Widget child,
  DragAndDropBuilderParameters params,
);

class DragAndDropList implements DragAndDropListInterface {
  /// The widget that is displayed at the top of the list.
  final Widget? header;

  /// The widget that is displayed at the bottom of the list.
  final Widget? footer;

  /// The widget that is displayed to the left of the list.
  final Widget? leftSide;

  /// The widget that is displayed to the right of the list.
  final Widget? rightSide;

  /// The widget to be displayed when a list is empty.
  /// If this is not null, it will override that set in [DragAndDropLists.contentsWhenEmpty].
  final Widget? contentsWhenEmpty;

  /// The widget to be displayed as the last element in the list that will accept
  /// a dragged item.
  final Widget? lastTarget;

  /// The decoration displayed around a list.
  /// If this is not null, it will override that set in [DragAndDropLists.listDecoration].
  final Decoration? decoration;

  /// An optional builder that replaces the default outer [Container].
  /// When provided, [decoration], [padding], and [margin] are ignored and the
  /// builder receives the inner content widget so you can wrap it however you
  /// like.
  final ListContainerBuilder? containerBuilder;

  /// The margin around the entire list.
  final EdgeInsets? margin;

  /// The padding inside the list (outer container).
  final EdgeInsets? padding;

  /// The clip behavior for the inner container.
  /// If this is not null, it will override that set in [DragAndDropLists.innerClipBehavior].
  /// By default, the inner container does not clip.
  final Clip? innerClipBehavior;

  /// The decoration for the inner content container.
  final Decoration? innerDecoration;

  /// The padding inside the inner content container.
  final EdgeInsets? innerPadding;

  /// The vertical alignment of the contents in this list.
  /// If this is not null, it will override that set in [DragAndDropLists.verticalAlignment].
  final CrossAxisAlignment verticalAlignment;

  /// The horizontal alignment of the contents in this list.
  /// If this is not null, it will override that set in [DragAndDropLists.horizontalAlignment].
  final MainAxisAlignment horizontalAlignment;

  /// The child elements that will be contained in this list.
  /// It is possible to not provide any children when an empty list is desired.
  @override
  final List<DragAndDropItem> children;

  /// Whether or not this item can be dragged.
  /// Set to true if it can be reordered.
  /// Set to false if it must remain fixed.
  @override
  final bool canDrag;
  @override
  final Key? key;
  DragAndDropList({
    required this.children,
    this.key,
    this.header,
    this.footer,
    this.leftSide,
    this.rightSide,
    this.contentsWhenEmpty,
    this.lastTarget,
    this.decoration,
    this.containerBuilder,
    this.margin,
    this.padding,
    this.innerClipBehavior,
    this.innerDecoration,
    this.innerPadding,
    this.horizontalAlignment = MainAxisAlignment.start,
    this.verticalAlignment = CrossAxisAlignment.start,
    this.canDrag = true,
  });

  @override
  Widget generateWidget(DragAndDropBuilderParameters params) {

    List<Widget> contents = _generateDragAndDropListInnerContents(params);
 

    Widget intrinsicHeight = IntrinsicHeight(
      child: Row(
        mainAxisAlignment: horizontalAlignment,
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: contents,
      ),
    );

    if (params.axis == Axis.horizontal) {
      intrinsicHeight = SizedBox(
        width: params.listWidth,
        child: intrinsicHeight,
      );
    }
    if (params.listInnerDecoration != null) {
      intrinsicHeight = Container(
        decoration: params.listInnerDecoration,
        child: intrinsicHeight,
      );
    }

    final innerColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: verticalAlignment,
      children: [
        if (header != null) Flexible(child: header!),

        Container(
          clipBehavior: innerClipBehavior ?? Clip.none,
          padding: innerPadding,
          decoration: innerDecoration,
          child: intrinsicHeight,
        ),

        if (footer != null) Flexible(child: footer!),
      ],
    );

    Widget listContainer;
    if (containerBuilder != null) {
      listContainer = KeyedSubtree(
        key: key,
        child: containerBuilder!(innerColumn, params),
      );
    } else {
      listContainer = Container(
        clipBehavior: Clip.hardEdge,
        key: key,
        width: params.axis == Axis.vertical
            ? double.infinity
            : params.listWidth - params.listPadding!.horizontal,
        decoration: decoration ?? params.listDecoration,
        padding: padding,
        margin: margin,
        child: innerColumn,
      );
    }

    return listContainer;
  }

  List<Widget> _generateDragAndDropListInnerContents(
      DragAndDropBuilderParameters parameters) {
    var contents = <Widget>[];
    if (leftSide != null) {
      contents.add(leftSide!);
    }
    if (children.isNotEmpty) {
      List<Widget> allChildren = <Widget>[];
      if (parameters.addLastItemTargetHeightToTop) {
        allChildren.add(Padding(
          padding: EdgeInsets.only(top: parameters.lastItemTargetHeight),
        ));
      }
      for (int i = 0; i < children.length; i++) {
        allChildren.add(DragAndDropItemWrapper(
          key: children[i].key,
          child: children[i],
          parameters: parameters,
        ));
        if (parameters.itemDivider != null && i < children.length - 1) {
          allChildren.add(parameters.itemDivider!);
        }
      }
      allChildren.add(DragAndDropItemTarget(
        parent: this,
        parameters: parameters,
        onReorderOrAdd: parameters.onItemDropOnLastTarget!,
        child: lastTarget ??
            Container(
              height: parameters.lastItemTargetHeight,
            ),
      ));
      contents.add(
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: verticalAlignment,
              mainAxisSize: MainAxisSize.max,
              children: allChildren,
            ),
          ),
        ),
      );
    } else {
      contents.add(
        Expanded(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: <Widget>[
                contentsWhenEmpty ??
                    const Text(
                      'Empty list',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                DragAndDropItemTarget(
                  parent: this,
                  parameters: parameters,
                  onReorderOrAdd: parameters.onItemDropOnLastTarget!,
                  child: lastTarget ??
                      Container(
                        height: parameters.lastItemTargetHeight,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (rightSide != null) {
      contents.add(rightSide!);
    }
    return contents;
  }
}
