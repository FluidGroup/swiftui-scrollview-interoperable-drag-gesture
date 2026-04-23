#if canImport(UIKit)
import Testing
import UIKit
@testable import SwiftUIScrollViewInteroperableDragGesture

@MainActor
private final class MockRecognizer: ScrollViewDragGestureRecognizing {
  var state: UIGestureRecognizer.State = .possible
  var trackingScrollView: UIScrollView?
  var pan: (_ScrollViewDragGestureRecognizer.PanDirection, diff: CGPoint) = ([], .zero)

  func consumePan() -> (_ScrollViewDragGestureRecognizer.PanDirection, diff: CGPoint) {
    let result = pan
    pan = ([], .zero)
    return result
  }
}

@MainActor
private func makeScrollView(contentSize: CGSize, bounds: CGRect = .init(x: 0, y: 0, width: 100, height: 100)) -> UIScrollView {
  let scrollView = UIScrollView(frame: bounds)
  scrollView.contentInsetAdjustmentBehavior = .never
  scrollView.contentSize = contentSize
  return scrollView
}

private let defaultConfig = ScrollViewInteroperableDragGestureConfiguration(
  ignoresScrollView: false,
  targetEdges: .all,
  sticksToEdges: true
)

@MainActor
private func runChanged(
  handler: DragGestureHandler,
  recognizer: MockRecognizer,
  direction: _ScrollViewDragGestureRecognizer.PanDirection,
  diff: CGPoint
) -> [DragGestureHandler.Value] {
  recognizer.state = .changed
  recognizer.pan = (direction, diff)
  var changes: [DragGestureHandler.Value] = []
  handler.handle(
    recognizer: recognizer,
    location: { .zero },
    velocity: { nil },
    onChange: { changes.append($0) },
    onEnd: { _ in }
  )
  return changes
}

@MainActor
@Suite("DragGestureHandler")
struct DragGestureHandlerTests {

  // MARK: - Basic scroll passthrough

  @Test("Mid-scroll drag does not activate outer gesture")
  func midScroll_dragUp_doesNotActivateOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)  // mid-scroll

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
    #expect(handler.tracking.translation == .zero)
    #expect(handler.tracking.isDraggingY == false)
  }

  // MARK: - Primary activation at edges

  @Test("Drag up at bottom edge activates outer and marks .bottom sticky")
  func atBottom_dragUp_activatesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(handler.tracking.stickingEdges == [.bottom])
    #expect(handler.tracking.isDraggingY == true)
    #expect(handler.tracking.translation == .init(width: 0, height: -10))
    #expect(changes.count == 1)
    #expect(changes.first?.translation == .init(width: 0, height: -10))
  }

  @Test("Drag down at top edge activates outer and marks .top sticky")
  func atTop_dragDown_activatesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .zero  // at top

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 10))

    #expect(handler.tracking.stickingEdges == [.top])
    #expect(handler.tracking.isDraggingY == true)
    #expect(handler.tracking.translation == .init(width: 0, height: 10))
    #expect(changes.count == 1)
  }

  @Test("Drag right at left edge activates outer and marks .left sticky")
  func atLeftEdge_dragRight_activatesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 100))
    scrollView.contentOffset = .zero

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .right, diff: .init(x: 10, y: 0))

    #expect(handler.tracking.stickingEdges == [.left])
    #expect(handler.tracking.isDraggingX == true)
    #expect(handler.tracking.translation == .init(width: 10, height: 0))
    #expect(changes.count == 1)
  }

  @Test("Drag left at right edge activates outer and marks .right sticky")
  func atRightEdge_dragLeft_activatesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 100))
    scrollView.contentOffset = .init(x: 200, y: 0)

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .left, diff: .init(x: -10, y: 0))

    #expect(handler.tracking.stickingEdges == [.right])
    #expect(handler.tracking.isDraggingX == true)
    #expect(handler.tracking.translation == .init(width: -10, height: 0))
    #expect(changes.count == 1)
  }

  // MARK: - sticksToEdges reversal

  @Test("After .up activation, reversing to .down continues outer via sticky")
  func afterUpActivation_reverseDown_continuesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Frame 1: activate via .up
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.stickingEdges == [.bottom])

    // Frame 2: reverse to .down — primary is false (not at top), sticky should kick in
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 5))

    #expect(handler.tracking.stickingEdges == [.bottom, .top])
    #expect(handler.tracking.translation == .init(width: 0, height: -5))  // -10 + 5
    #expect(changes.count == 1)
  }

  @Test("Without sticksToEdges, reversal does not continue outer")
  func withoutSticky_reverseDown_stopsOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: false
    ))
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Frame 1: activate via .up
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    // Frame 2: reverse to .down — no sticky, should not continue
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 5))

    #expect(changes.isEmpty)
    #expect(handler.tracking.translation == .init(width: 0, height: -10))  // not incremented
  }

  // MARK: - targetEdges restriction

  @Test("targetEdges = [.top] does not activate .up at bottom")
  func targetEdgesTopOnly_dragUpAtBottom_doesNotActivate() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: .init(
      ignoresScrollView: false,
      targetEdges: [.top],
      sticksToEdges: true
    ))
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
  }

  @Test("targetEdges = [.top] activates .down at top")
  func targetEdgesTopOnly_dragDownAtTop_activates() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .zero

    let handler = DragGestureHandler(configuration: .init(
      ignoresScrollView: false,
      targetEdges: [.top],
      sticksToEdges: true
    ))
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 10))

    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.top])
  }

  // MARK: - isScrollLockEnabled

  @Test("isScrollLockEnabled makes outer always own the gesture")
  func isScrollLockEnabled_alwaysOwnsGesture() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)  // mid-scroll

    let handler = DragGestureHandler(configuration: defaultConfig)
    handler.isScrollLockEnabled = true
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.count == 1)
    #expect(handler.tracking.translation == .init(width: 0, height: -10))
  }

  // MARK: - No scroll view path

  @Test("Without scroll view, translation always updates")
  func noScrollView_alwaysUpdates() {
    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = nil

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.count == 1)
    #expect(handler.tracking.isDraggingX == true)
    #expect(handler.tracking.isDraggingY == true)
    #expect(handler.tracking.translation == .init(width: 0, height: -10))
  }

  // MARK: - Gesture end

  @Test("On .ended, onEnd fires and tracking is purged")
  func ended_purgesTracking() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Activate
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.stickingEdges == [.bottom])

    // End
    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    var endCalls: [DragGestureHandler.Value] = []
    handler.handle(
      recognizer: recognizer,
      location: { .init(x: 1, y: 2) },
      velocity: { .init(x: 100, y: -200) },
      onChange: { _ in },
      onEnd: { endCalls.append($0) }
    )

    #expect(endCalls.count == 1)
    #expect(endCalls.first?.translation == .init(width: 0, height: -10))
    #expect(handler.tracking.stickingEdges.isEmpty)
    #expect(handler.tracking.translation == .zero)
  }

  @Test("On .ended, velocity is zeroed for axes not dragged")
  func ended_velocityZeroedForIdleAxes() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Only Y drag
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.isDraggingY == true)
    #expect(handler.tracking.isDraggingX == false)

    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    var endCalls: [DragGestureHandler.Value] = []
    handler.handle(
      recognizer: recognizer,
      location: { .zero },
      velocity: { .init(x: 500, y: -300) },
      onChange: { _ in },
      onEnd: { endCalls.append($0) }
    )

    let value = try! #require(endCalls.first)
    #expect(value.velocity.width == 0)  // X axis not dragged, velocity zeroed
    #expect(value.velocity.height == -300)
  }
}
#endif
