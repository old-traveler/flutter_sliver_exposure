import 'dart:collection';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_sliver_exposure/model/exposure_model.dart';

typedef SingleScrollCallback = void Function(
    IndexRange range, ScrollNotification scrollNotification);

typedef SliverScrollCallback = void Function(
    List<IndexRange>, ScrollNotification scrollNotification);

typedef ExposureStartCallback = void Function(ExposureStartIndex index);

typedef ExposureEndCallback = void Function(ExposureEndIndex index);

typedef ExposureReferee = bool Function(
    ExposureStartIndex index, double paintExtent, double maxPaintExtent);

class SingleExposureListener extends StatefulWidget {
  final SingleScrollCallback scrollCallback;
  final ExposureReferee exposureReferee;
  final ExposureStartCallback exposureStartCallback;
  final ExposureEndCallback exposureEndCallback;
  final Widget child;
  final Axis scrollDirection;
  final ScrollController scrollController;

  const SingleExposureListener(
      {Key key,
      this.scrollCallback,
      this.exposureReferee,
      this.exposureStartCallback,
      this.exposureEndCallback,
      this.child,
      this.scrollDirection: Axis.vertical,
      this.scrollController})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SingleExposureListener();
  }
}

class _SingleExposureListener extends State<SingleExposureListener>
    with _ExposureMixin {
  int _firstExposureIndex;
  int _lastExposureIndex;
  Map<int, int> visibleMap = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.scrollController.position.didStartScroll();
      widget.scrollController.position.didEndScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
        child: widget.child, onNotification: _onNotification);
  }

  bool _onNotification(ScrollNotification notice) {
    final int exposureTime = DateTime.now().millisecondsSinceEpoch;
    final element =
        findElementByType<SliverMultiBoxAdaptorElement>(notice.context);
    if (element != null) {
      final indexRange = _visitSliverMultiBoxAdaptorElement(
          element,
          notice.metrics.pixels,
          notice.metrics.pixels + notice.metrics.viewportDimension,
          widget.scrollDirection,
          widget.exposureReferee,
          exposureTime,
          0);
      widget.scrollCallback?.call(indexRange, notice);
      _dispatchExposureEvent(indexRange, exposureTime);
    }
    return false;
  }

  void _dispatchExposureEvent(IndexRange indexRange, int exposureTime) {
    if (indexRange.firstIndex <= indexRange.lastIndex) {
      for (int i = indexRange.firstIndex; i <= indexRange.lastIndex; i++) {
        if (_firstExposureIndex == null ||
            i < _firstExposureIndex ||
            i > _lastExposureIndex) {
          widget.exposureStartCallback
              ?.call(ExposureStartIndex(0, i, exposureTime));
          visibleMap[i] = exposureTime;
        }
      }
    }
    _dispatchExposureEnd(exposureTime,
        firstIndex: indexRange.firstIndex, lastIndex: indexRange.lastIndex);

    this._firstExposureIndex = indexRange.firstIndex <= indexRange.lastIndex
        ? indexRange.firstIndex
        : null;
    this._lastExposureIndex = indexRange.lastIndex;
  }

  @override
  void dispose() {
    _dispatchExposureEnd(DateTime.now().millisecondsSinceEpoch, dispose: true);
    super.dispose();
  }

  void _dispatchExposureEnd(int exposureTime,
      {int firstIndex, int lastIndex, bool dispose = false}) {
    if (_firstExposureIndex != null)
      for (int i = _firstExposureIndex; i <= _lastExposureIndex; i++) {
        if (dispose ||
            firstIndex > lastIndex ||
            i < firstIndex ||
            i > lastIndex) {
          final startTime = visibleMap.remove(i);
          widget.exposureEndCallback?.call(
              ExposureEndIndex(0, i, exposureTime, exposureTime - startTime));
        }
      }
  }
}

class SliverExposureListener extends StatefulWidget {
  final SliverScrollCallback scrollCallback;
  final ExposureReferee exposureReferee;
  final ExposureStartCallback exposureStartCallback;
  final ExposureEndCallback exposureEndCallback;
  final Widget child;
  final Axis scrollDirection;
  final ScrollController scrollController;

  const SliverExposureListener(
      {Key key,
      this.scrollCallback,
      this.exposureReferee,
      this.child,
      this.scrollDirection: Axis.vertical,
      this.exposureStartCallback,
      this.exposureEndCallback,
      this.scrollController})
      : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _SliverExposureListenerState();
  }
}

class _Point {
  final int parentIndex;
  final int itemIndex;
  final int time;

  _Point(this.parentIndex, this.itemIndex, this.time);

  @override
  bool operator ==(other) {
    if (other is! _Point) {
      return false;
    }
    return this.parentIndex == other.parentIndex &&
        this.itemIndex == other.itemIndex;
  }

  @override
  int get hashCode => hashValues(parentIndex, itemIndex);
}

class _SliverExposureListenerState extends State<SliverExposureListener>
    with _ExposureMixin {
  Set<_Point> visibleSet = Set();
  Set<_Point> oldSet;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.scrollController.position.didStartScroll();
      widget.scrollController.position.didEndScroll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener(
        child: widget.child, onNotification: _onNotification);
  }

  bool _onNotification(ScrollNotification notice) {
    final int exposureTime = DateTime.now().millisecondsSinceEpoch;
    final viewPortElement =
        findElementByType<MultiChildRenderObjectElement>(notice.context);
    assert(viewPortElement != null);
    int parentIndex = 0;
    final indexRanges = <IndexRange>[];
    oldSet = Set.from(visibleSet);
    double totalScrollExtent = 0;
    viewPortElement.visitChildElements((itemElement) {
      assert(itemElement.renderObject is RenderSliver);
      final geometry = (itemElement.renderObject as RenderSliver).geometry;
      if (geometry.visible) {
        if (itemElement is SliverMultiBoxAdaptorElement) {
          final indexRange = _visitSliverMultiBoxAdaptorElement(
              itemElement,
              notice.metrics.pixels - totalScrollExtent,
              notice.metrics.pixels - totalScrollExtent + geometry.paintExtent,
              widget.scrollDirection,
              widget.exposureReferee,
              exposureTime,
              parentIndex);
          indexRanges.add(indexRange);
          _dispatchExposureStartEventByIndexRange(indexRange, exposureTime);
        } else {
          bool isExposure = widget.exposureReferee != null
              ? widget.exposureReferee(
                  ExposureStartIndex(parentIndex, 0, exposureTime),
                  geometry.paintExtent,
                  geometry.maxPaintExtent)
              : geometry.paintExtent == geometry.maxPaintExtent;
          if (isExposure) {
            final indexRange = IndexRange(parentIndex, 0, 0);
            indexRanges.add(indexRange);
            _dispatchExposureStartEvent(parentIndex, 0, exposureTime);
          }
        }
      }
      totalScrollExtent += geometry.scrollExtent;
      parentIndex++;
    });
    _dispatchExposureEndEvent(oldSet, exposureTime);
    widget.scrollCallback?.call(indexRanges, notice);
    return false;
  }

  void _dispatchExposureStartEventByIndexRange(
      IndexRange indexRange, int exposureTime) {
    if (indexRange.firstIndex > indexRange.lastIndex) {
      return;
    }
    for (int i = indexRange.firstIndex; i <= indexRange.lastIndex; i++) {
      _dispatchExposureStartEvent(indexRange.parentIndex, i, exposureTime);
    }
  }

  void _dispatchExposureStartEvent(
      int parentIndex, int itemIndex, int exposureTime) {
    final point = _Point(parentIndex, itemIndex, exposureTime);
    if (!visibleSet.contains(point)) {
      visibleSet.add(point);
      widget.exposureStartCallback
          ?.call(ExposureStartIndex(parentIndex, itemIndex, exposureTime));
    } else {
      oldSet.remove(point);
    }
  }

  void _dispatchExposureEndEvent(Set<_Point> set, int exposureTime) {
    if (widget.exposureEndCallback == null) return;
    set.forEach((item) {
      widget.exposureEndCallback(ExposureEndIndex(item.parentIndex,
          item.itemIndex, exposureTime, exposureTime - item.time));
    });
    if (visibleSet == set) {
      visibleSet.clear();
    } else {
      visibleSet.removeAll(set);
    }
  }

  @override
  void dispose() {
    _dispatchExposureEndEvent(
        visibleSet, DateTime.now().millisecondsSinceEpoch);
    super.dispose();
  }
}

mixin _ExposureMixin {
  IndexRange _visitSliverMultiBoxAdaptorElement(
      SliverMultiBoxAdaptorElement sliverMultiBoxAdaptorElement,
      double portF,
      double portE,
      Axis axis,
      ExposureReferee exposureReferee,
      int exposureTime,
      int parentIndex) {
    if (sliverMultiBoxAdaptorElement == null) return null;
    int firstIndex = sliverMultiBoxAdaptorElement.childCount;
    assert(firstIndex != null);
    int endIndex = -1;
    void onVisitChildren(Element element) {
      final SliverMultiBoxAdaptorParentData parentData =
          element?.renderObject?.parentData;
      if (parentData != null) {
        double boundF = parentData.layoutOffset;
        double itemLength = axis == Axis.vertical
            ? element.renderObject.paintBounds.height
            : element.renderObject.paintBounds.width;
        double boundE = itemLength + boundF;
        double paintExtent = max(min(boundE, portE) - max(boundF, portF), 0);
        double maxPaintExtent = itemLength;
        bool isExposure = exposureReferee != null
            ? exposureReferee(
                ExposureStartIndex(parentIndex, parentData.index, exposureTime),
                paintExtent,
                maxPaintExtent)
            : paintExtent == maxPaintExtent;

        if (isExposure) {
          firstIndex = min(firstIndex, parentData.index);

          endIndex = max(endIndex, parentData.index);
        }
      }
    }

    sliverMultiBoxAdaptorElement.visitChildren(onVisitChildren);
    return IndexRange(parentIndex, firstIndex, endIndex);
  }

  T findElementByType<T extends Element>(Element element) {
    if (element is T) {
      return element;
    }
    T target;
    element.visitChildElements((child) {
      target ??= findElementByType<T>(child);
    });
    return target;
  }
}
