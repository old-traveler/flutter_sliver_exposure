class IndexRange {
  // 父节点下标
  final int parentIndex;

  // 第一个可见的元素下标
  final int firstIndex;

  // 最后一个可见元素下标
  final int lastIndex;

  IndexRange(this.parentIndex, this.firstIndex, this.lastIndex);

  IndexRange.parentIndex(this.parentIndex, IndexRange other)
      : this.firstIndex = other.firstIndex,
        this.lastIndex = other.lastIndex;
}

class ExposureStartIndex {
  // 父节点下标
  final int parentIndex;

  // 曝光子节点下标
  final int itemIndex;

  // 曝光开始事件
  final int exposureStartTime;

  ExposureStartIndex(this.parentIndex, this.itemIndex, this.exposureStartTime);
}

class ExposureEndIndex {
  // 父节点下标
  final int parentIndex;

  // 曝光子节点下标
  final int itemIndex;

  // 曝光结束事件
  final int exposureEndTime;

  // 曝光时长
  final int exposureTime;

  ExposureEndIndex(this.parentIndex, this.itemIndex, this.exposureEndTime, this.exposureTime);

}

