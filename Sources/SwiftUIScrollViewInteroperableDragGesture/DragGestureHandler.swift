import UIKit

public struct ScrollViewInteroperableDragGestureValue: Equatable, Sendable {

  public let translation: CGSize
  public let location: CGPoint
  public internal(set) var velocity: CGSize

  public init(translation: CGSize, location: CGPoint, velocity: CGSize) {
    self.translation = translation
    self.location = location
    self.velocity = velocity
  }
}

public struct ScrollViewInteroperableDragGestureConfiguration: Sendable {

  public var targetEdges: ScrollViewEdge
  public var ignoresScrollView: Bool
  public var sticksToEdges: Bool

  public init(
    ignoresScrollView: Bool,
    targetEdges: ScrollViewEdge,
    sticksToEdges: Bool
  ) {
    self.ignoresScrollView = ignoresScrollView
    self.sticksToEdges = sticksToEdges
    self.targetEdges = targetEdges
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
  }

  var tracking: Tracking = .init()
  var configuration: Configuration
  var isScrollLockEnabled: Bool = false

  init(configuration: Configuration) {
    self.configuration = configuration
  }

  func purgeTrackingState() {
    tracking = .init()
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

      if let scrollView = recognizer.trackingScrollView {

        let scrollController = ScrollController(scrollView: scrollView)

        tracking.currentScrollController = scrollController

        let scrollableEdges = scrollView.scrollableEdges

        if isScrollLockEnabled {
          scrollController.lockScrolling(direction: [.horizontal, .vertical])

          tracking.translation.width += diff.x
          tracking.translation.height += diff.y

          onChange(makeValue(translation: tracking.translation))

          return
        }

        // handling scrolling in scrollview
        if panDirection.contains(.up) {

          if (configuration.targetEdges.contains(.bottom) && scrollableEdges.contains(.bottom) == false)
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.top))
          {

            scrollController.lockScrolling(direction: .vertical)

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.top) == false {
              scrollController.scrollTo(edge: .bottom)
            }

            tracking.isDraggingY = true

            tracking.translation.height += diff.y
            tracking.stickingEdges.insert(.bottom)
            onChange(makeValue(translation: tracking.translation))
          } else {

            scrollController.unlockScrolling(direction: .vertical)
            tracking.isDraggingY = false

          }

        }

        if panDirection.contains(.down) {

          if (configuration.targetEdges.contains(.top) && scrollableEdges.contains(.top) == false)
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom))
          {

            scrollController.lockScrolling(direction: .vertical)

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom) == false {
              scrollController.scrollTo(edge: .top)
            }

            tracking.translation.height += diff.y
            tracking.isDraggingY = true
            tracking.stickingEdges.insert(.top)

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .vertical)
            tracking.isDraggingY = false
          }
        }

        if panDirection.contains(.left) {

          if (configuration.targetEdges.contains(.right) && scrollableEdges.contains(.right) == false)
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.left))
          {

            scrollController.lockScrolling(direction: .horizontal)

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.left) == false {
              scrollController.scrollTo(edge: .right)
            }

            tracking.isDraggingX = true
            tracking.translation.width += diff.x
            tracking.stickingEdges.insert(.right)

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .horizontal)
            tracking.isDraggingX = false

          }

        }

        if panDirection.contains(.right) {

          if (configuration.targetEdges.contains(.left) && scrollableEdges.contains(.left) == false)
            || (configuration.sticksToEdges && tracking.stickingEdges.contains(.right))
          {

            scrollController.lockScrolling(direction: .horizontal)

            if configuration.sticksToEdges && tracking.stickingEdges.contains(.right) == false {
              scrollController.scrollTo(edge: .left)
            }

            tracking.isDraggingX = true
            tracking.translation.width += diff.x
            tracking.stickingEdges.insert(.left)

            onChange(makeValue(translation: tracking.translation))

          } else {
            scrollController.unlockScrolling(direction: .horizontal)
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

      var value = Value(
        translation: tracking.translation,
        location: location(),
        velocity: { .init(width: $0.x, height: $0.y) }(velocity() ?? .zero)
      )

      if tracking.isDraggingX == false {
        value.velocity.width = 0
      }

      if tracking.isDraggingY == false {
        value.velocity.height = 0
      }

      onEnd(value)

      purgeTrackingState()

    @unknown default:
      break
    }
  }
}
