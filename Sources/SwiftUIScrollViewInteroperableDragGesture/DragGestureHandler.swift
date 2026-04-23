import UIKit

public struct ScrollViewInteroperableDragGestureValue: Equatable, Sendable {

  public let translation: CGSize
  public let location: CGPoint
  /// Raw velocity reported by the underlying gesture recognizer in the chosen
  /// coordinate space. This is not filtered by which axes the outer handler
  /// happened to own at the end of the gesture.
  public internal(set) var velocity: CGSize

  public init(translation: CGSize, location: CGPoint, velocity: CGSize) {
    self.translation = translation
    self.location = location
    self.velocity = velocity
  }
}

public enum EdgeActivationMode: Sendable {
  /// Activate the external handler whenever the scroll view reaches a target edge during the gesture.
  case anytime
  /// Activate only if the scroll view was already at the target edge when the gesture began.
  /// If the gesture started mid-content, the external handler will not fire for this session,
  /// even if the scroll view reaches an edge mid-drag.
  case onlyAtGestureStart
}

public struct ScrollViewInteroperableDragGestureConfiguration: Sendable {

  public var targetEdges: ScrollViewEdge
  public var ignoresScrollView: Bool
  public var sticksToEdges: Bool
  public var edgeActivationMode: EdgeActivationMode
  /// Minimum distance (in points) the finger must travel from its touch-down
  /// location before the gesture starts forwarding motion. `0` disables the
  /// gate (default) and matches the underlying UIPanGestureRecognizer's own
  /// minimum. Useful to avoid micro-movements momentarily triggering the outer
  /// drag on light touches.
  public var minimumActivationDistance: CGFloat

  public init(
    ignoresScrollView: Bool,
    targetEdges: ScrollViewEdge,
    sticksToEdges: Bool,
    edgeActivationMode: EdgeActivationMode = .anytime,
    minimumActivationDistance: CGFloat = 0
  ) {
    self.ignoresScrollView = ignoresScrollView
    self.sticksToEdges = sticksToEdges
    self.targetEdges = targetEdges
    self.edgeActivationMode = edgeActivationMode
    self.minimumActivationDistance = minimumActivationDistance
  }
}

// Abstraction over `_ScrollViewDragGestureRecognizer` so that the handler can
// be driven by a test double. Production code uses the real recognizer.
protocol ScrollViewDragGestureRecognizing: AnyObject {
  @MainActor var state: UIGestureRecognizer.State { get }
  @MainActor var trackingScrollView: UIScrollView? { get }
  @MainActor func consumePan() -> (_ScrollViewDragGestureRecognizer.PanDirection, diff: CGPoint)
}

@MainActor
final class DragGestureHandler {

  typealias Value = ScrollViewInteroperableDragGestureValue
  typealias Configuration = ScrollViewInteroperableDragGestureConfiguration

  struct Tracking {
    var isDraggingX: Bool = false
    var isDraggingY: Bool = false
    var currentScrollController: ScrollController?
    var translation: CGSize = .zero
    var stickingEdges: ScrollViewEdge = []
    /// Scrollable edges captured on the first frame of the gesture.
    /// `nil` until a frame with a tracking scroll view is observed.
    var initialScrollableEdges: ScrollViewEdge? = nil
    /// Captured once per gesture so we can restore the scroll view's indicator
    /// visibility after locking hides it.
    var initialShowsVerticalScrollIndicator: Bool? = nil
    var initialShowsHorizontalScrollIndicator: Bool? = nil
    /// Raw accumulated pan translation used only until
    /// `minimumActivationDistance` is crossed. Discarded afterwards.
    var preActivationTranslation: CGSize = .zero
    var hasPassedActivationThreshold: Bool = false
  }

  var tracking: Tracking = .init()
  var configuration: Configuration
  var isScrollLockEnabled: Bool = false

  var onStickingEdgesChange: ((ScrollViewEdge) -> Void)?

  init(configuration: Configuration) {
    self.configuration = configuration
  }

  func purgeTrackingState() {
    let hadStickingEdges = tracking.stickingEdges
    tracking = .init()
    if hadStickingEdges.isEmpty == false {
      onStickingEdgesChange?([])
    }
  }

  private func setStickingEdges(_ edges: ScrollViewEdge) {
    guard tracking.stickingEdges != edges else { return }
    tracking.stickingEdges = edges
    onStickingEdgesChange?(edges)
  }

  func overrideStickingEdges(_ edges: ScrollViewEdge) {
    setStickingEdges(edges)
  }

  func shouldRecognizeSimultaneously(
    _ gestureRecognizer: UIGestureRecognizer,
    with otherGestureRecognizer: UIGestureRecognizer
  ) -> Bool {

    guard gestureRecognizer is _ScrollViewDragGestureRecognizer else {
      assertionFailure("\(gestureRecognizer)")
      return false
    }

    guard !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer) else {
      return false
    }

    // Allow simultaneous recognition with a UIScrollView's pan gesture so that
    // scrolling works alongside this gesture. `trackingScrollView` cannot be
    // used here because `shouldRecognizeSimultaneouslyWith` may be invoked
    // before this recognizer's `touchesBegan` runs.
    if otherGestureRecognizer is UIPanGestureRecognizer,
       otherGestureRecognizer.view is UIScrollView {
      return configuration.ignoresScrollView == false
    }

    return false
  }

  func handle(
    recognizer: some ScrollViewDragGestureRecognizing,
    location: () -> CGPoint,
    velocity: () -> CGPoint?,
    onChange: (Value) -> Void,
    onEnd: (Value) -> Void
  ) {

    switch recognizer.state {
    case .possible:
      break
    case .began:
      fallthrough
    case .changed:

      func makeValue(translation: CGSize) -> Value {
        let sourceVelocity = velocity() ?? .zero
        return Value(
          translation: translation,
          location: location(),
          velocity: .init(width: sourceVelocity.x, height: sourceVelocity.y)
        )
      }

      let (panDirection, diff) = recognizer.consumePan()

      // Capture initial scroll-view state on the first frame that sees a
      // scroll view, BEFORE any activation-distance gating. We want the
      // snapshot to reflect touches-began state, not post-wobble state.
      if let scrollView = recognizer.trackingScrollView, tracking.initialScrollableEdges == nil {
        tracking.initialScrollableEdges = scrollView.scrollableEdges
        tracking.initialShowsVerticalScrollIndicator = scrollView.showsVerticalScrollIndicator
        tracking.initialShowsHorizontalScrollIndicator = scrollView.showsHorizontalScrollIndicator
      }

      // Activation-distance gate: discard the first few points of motion so
      // micro-movements on a light touch don't flicker the outer drag. A
      // consumer-imposed `isScrollLockEnabled` bypasses the gate since it
      // signals an explicit request to own the gesture immediately.
      if configuration.minimumActivationDistance > 0,
         tracking.hasPassedActivationThreshold == false,
         isScrollLockEnabled == false {
        tracking.preActivationTranslation.width += diff.x
        tracking.preActivationTranslation.height += diff.y
        let magnitude = hypot(
          tracking.preActivationTranslation.width,
          tracking.preActivationTranslation.height
        )
        if magnitude < configuration.minimumActivationDistance {
          return
        }
        tracking.hasPassedActivationThreshold = true
      }

      if let scrollView = recognizer.trackingScrollView {

        let scrollController = ScrollController(scrollView: scrollView)

        tracking.currentScrollController = scrollController

        let scrollableEdges = scrollView.scrollableEdges

        let restoredVerticalIndicator = tracking.initialShowsVerticalScrollIndicator ?? scrollView.showsVerticalScrollIndicator
        let restoredHorizontalIndicator = tracking.initialShowsHorizontalScrollIndicator ?? scrollView.showsHorizontalScrollIndicator

        if isScrollLockEnabled {
          scrollController.lockScrolling(direction: [.horizontal, .vertical])
          scrollView.showsVerticalScrollIndicator = false
          scrollView.showsHorizontalScrollIndicator = false

          tracking.translation.width += diff.x
          tracking.translation.height += diff.y

          onChange(makeValue(translation: tracking.translation))

          return
        }

        func allowsPrimary(oppositeEdge: ScrollViewEdge) -> Bool {
          switch configuration.edgeActivationMode {
          case .anytime:
            return true
          case .onlyAtGestureStart:
            return tracking.initialScrollableEdges?.contains(oppositeEdge) == false
          }
        }

        // handling scrolling in scrollview
        if panDirection.contains(.up) {

          if (configuration.targetEdges.contains(.bottom) && scrollableEdges.contains(.bottom) == false && allowsPrimary(oppositeEdge: .bottom))
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.top))
          {

            scrollController.lockScrolling(direction: .vertical)
            scrollView.showsVerticalScrollIndicator = false

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.top) == false {
              scrollController.scrollTo(edge: .bottom)
            }

            tracking.isDraggingY = true

            tracking.translation.height += diff.y
            setStickingEdges(tracking.stickingEdges.union(.bottom))
            onChange(makeValue(translation: tracking.translation))
          } else {

            scrollController.unlockScrolling(direction: .vertical)
            scrollView.showsVerticalScrollIndicator = restoredVerticalIndicator
            tracking.isDraggingY = false

          }

        }

        if panDirection.contains(.down) {

          if (configuration.targetEdges.contains(.top) && scrollableEdges.contains(.top) == false && allowsPrimary(oppositeEdge: .top))
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom))
          {

            scrollController.lockScrolling(direction: .vertical)
            scrollView.showsVerticalScrollIndicator = false

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom) == false {
              scrollController.scrollTo(edge: .top)
            }

            tracking.translation.height += diff.y
            tracking.isDraggingY = true
            setStickingEdges(tracking.stickingEdges.union(.top))

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .vertical)
            scrollView.showsVerticalScrollIndicator = restoredVerticalIndicator
            tracking.isDraggingY = false
          }
        }

        if panDirection.contains(.left) {

          if (configuration.targetEdges.contains(.right) && scrollableEdges.contains(.right) == false && allowsPrimary(oppositeEdge: .right))
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.left))
          {

            scrollController.lockScrolling(direction: .horizontal)
            scrollView.showsHorizontalScrollIndicator = false

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.left) == false {
              scrollController.scrollTo(edge: .right)
            }

            tracking.isDraggingX = true
            tracking.translation.width += diff.x
            setStickingEdges(tracking.stickingEdges.union(.right))

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .horizontal)
            scrollView.showsHorizontalScrollIndicator = restoredHorizontalIndicator
            tracking.isDraggingX = false

          }

        }

        if panDirection.contains(.right) {

          if (configuration.targetEdges.contains(.left) && scrollableEdges.contains(.left) == false && allowsPrimary(oppositeEdge: .left))
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.right))
          {

            scrollController.lockScrolling(direction: .horizontal)
            scrollView.showsHorizontalScrollIndicator = false

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.right) == false {
              scrollController.scrollTo(edge: .left)
            }

            tracking.isDraggingX = true
            tracking.translation.width += diff.x
            setStickingEdges(tracking.stickingEdges.union(.left))

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .horizontal)
            scrollView.showsHorizontalScrollIndicator = restoredHorizontalIndicator
            tracking.isDraggingX = false

          }

        }

      } else {
        tracking.isDraggingX = true
        tracking.isDraggingY = true

        tracking.translation.width += diff.x
        tracking.translation.height += diff.y

        onChange(makeValue(translation: tracking.translation))
      }

    case .ended, .cancelled, .failed:

      // Restore scroll indicators to whatever state they had when the gesture
      // began. Safe to run even if no indicator was ever hidden, since setting
      // a bool property to its existing value is a no-op.
      if let scrollView = tracking.currentScrollController?.scrollView {
        if let v = tracking.initialShowsVerticalScrollIndicator {
          scrollView.showsVerticalScrollIndicator = v
        }
        if let h = tracking.initialShowsHorizontalScrollIndicator {
          scrollView.showsHorizontalScrollIndicator = h
        }
      }

      let value = Value(
        translation: tracking.translation,
        location: location(),
        velocity: { .init(width: $0.x, height: $0.y) }(velocity() ?? .zero)
      )

      onEnd(value)

      purgeTrackingState()

    @unknown default:
      break
    }
  }
}
