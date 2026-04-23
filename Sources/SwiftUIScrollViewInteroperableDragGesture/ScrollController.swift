import UIKit

@MainActor
final class ScrollController {

  enum Edge {
    case top
    case bottom
    case left
    case right
  }

  struct LockingDirection: OptionSet {
    let rawValue: Int

    static let vertical = LockingDirection(rawValue: 1 << 0)
    static let horizontal = LockingDirection(rawValue: 1 << 1)
  }

  private var scrollObserver: NSKeyValueObservation!
  private(set) var lockingDirection: LockingDirection = []
  // The contentOffset the scroll view is pinned to while locked. Captured
  // (clamped into the non-bouncing range) when a direction is first locked,
  // and overridden by explicit `scrollTo` / `setContentOffset` calls.
  private var lockedContentOffset: CGPoint?
  let scrollView: UIScrollView

  init(scrollView: UIScrollView) {
    self.scrollView = scrollView
    scrollObserver = scrollView.observe(\.contentOffset, options: [.new]) {
      [weak self, weak _scrollView = scrollView] scrollView, change in

      guard let scrollView = _scrollView else { return }
      guard let self = self else { return }

      MainActor.assumeIsolated {
        self.handleScrollViewEvent(scrollView: scrollView, change: change)
      }
    }
  }

  deinit {
    MainActor.assumeIsolated {
      endTracking()
    }
  }

  func lockScrolling(direction: LockingDirection) {
    let newlyLocking = direction.subtracting(lockingDirection)
    if newlyLocking.isEmpty == false {
      // Clamp into the non-bouncing range so that locking never pins the
      // scroll view at a rubber-band position.
      let clamped = clampedToBounds(scrollView.contentOffset)
      var newLockedOffset = lockedContentOffset ?? clamped
      if newlyLocking.contains(.vertical) {
        newLockedOffset.y = clamped.y
      }
      if newlyLocking.contains(.horizontal) {
        newLockedOffset.x = clamped.x
      }
      lockedContentOffset = newLockedOffset
      if scrollView.contentOffset != newLockedOffset {
        setContentOffset(newLockedOffset)
      }
    }
    lockingDirection.insert(direction)
  }

  private func clampedToBounds(_ offset: CGPoint) -> CGPoint {
    let contentInset = scrollView.adjustedContentInset
    let minY = -contentInset.top
    let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + contentInset.bottom)
    let minX = -contentInset.left
    let maxX = max(minX, scrollView.contentSize.width - scrollView.bounds.width + contentInset.right)
    return CGPoint(
      x: min(max(offset.x, minX), maxX),
      y: min(max(offset.y, minY), maxY)
    )
  }

  func unlockScrolling(direction: LockingDirection) {
    lockingDirection.remove(direction)
    if lockingDirection.isEmpty {
      lockedContentOffset = nil
    }
  }

  func setShowsVerticalScrollIndicator(_ flag: Bool) {
    scrollView.showsVerticalScrollIndicator = flag
  }

  func endTracking() {
    unlockScrolling(direction: [.vertical, .horizontal])
    scrollObserver.invalidate()
  }

  func scrollTo(edge: Edge) {
    let contentInset = scrollView.adjustedContentInset
    var offset = scrollView.contentOffset
    switch edge {
    case .top:
      offset.y = -contentInset.top
    case .bottom:
      offset.y = scrollView.contentSize.height - scrollView.bounds.height + contentInset.bottom
    case .left:
      offset.x = -contentInset.left
    case .right:
      offset.x = scrollView.contentSize.width - scrollView.bounds.width + contentInset.right
    }
    setContentOffset(offset)
  }

  func setContentOffset(_ offset: CGPoint) {
    let previous = lockingDirection
    lockingDirection = []
    defer {
      lockingDirection = previous
    }
    scrollView.contentOffset = offset
    if previous.isEmpty == false {
      lockedContentOffset = offset
    }
  }

  private func handleScrollViewEvent(
    scrollView: UIScrollView,
    change: NSKeyValueObservedChange<CGPoint>
  ) {

    guard lockingDirection.isEmpty == false else {
      return
    }

    guard let lockedContentOffset else {
      return
    }

    var fixedOffset = scrollView.contentOffset

    if lockingDirection.contains(.vertical) {
      fixedOffset.y = lockedContentOffset.y
    }

    if lockingDirection.contains(.horizontal) {
      fixedOffset.x = lockedContentOffset.x
    }

    guard fixedOffset != scrollView.contentOffset else {
      return
    }

    scrollView.setContentOffset(fixedOffset, animated: false)
  }

}
