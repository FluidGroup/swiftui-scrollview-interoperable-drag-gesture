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

  // MARK: - edgeActivationMode = .onlyAtGestureStart

  private static let onlyAtStartConfig = ScrollViewInteroperableDragGestureConfiguration(
    ignoresScrollView: false,
    targetEdges: .all,
    sticksToEdges: true,
    edgeActivationMode: .onlyAtGestureStart
  )

  @Test("onlyAtGestureStart: mid-content start stays internal even after reaching bottom")
  func onlyAtStart_midContentStart_doesNotActivate_evenAtEdge() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)  // mid-scroll, bottom still scrollable

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Frame 1: mid-content, drag up — should not activate
    let changes1 = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(changes1.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)

    // Simulate the scroll view reaching the bottom mid-gesture
    scrollView.contentOffset = .init(x: 0, y: 200)

    // Frame 2: still dragging up, scroll view is now at bottom — must NOT activate
    let changes2 = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(changes2.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
    #expect(handler.tracking.translation == .zero)
    #expect(handler.tracking.isDraggingY == false)
  }

  @Test("onlyAtGestureStart: start at bottom edge still activates outer on .up")
  func onlyAtStart_startAtBottom_dragUp_activatesOuter() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.bottom])
    #expect(handler.tracking.translation == .init(width: 0, height: -10))
  }

  @Test("onlyAtGestureStart: sticky reversal still works once activated")
  func onlyAtStart_stickyReversal_afterActivation() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.stickingEdges == [.bottom])

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 5))

    #expect(handler.tracking.stickingEdges == [.bottom, .top])
    #expect(handler.tracking.translation == .init(width: 0, height: -5))
    #expect(changes.count == 1)
  }

  @Test("onlyAtGestureStart: initial edges are reset per gesture via purge")
  func onlyAtStart_perGestureSnapshotReset() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)  // mid-content

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Gesture 1: mid-content start, should not activate
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.stickingEdges.isEmpty)

    // End the gesture → purge
    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    handler.handle(
      recognizer: recognizer,
      location: { .zero },
      velocity: { nil },
      onChange: { _ in },
      onEnd: { _ in }
    )
    #expect(handler.tracking.initialScrollableEdges == nil)

    // Gesture 2: now at bottom, should activate
    scrollView.contentOffset = .init(x: 0, y: 200)
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.bottom])
  }

  @Test("onlyAtGestureStart: horizontal — start at right edge activates .left")
  func onlyAtStart_horizontal_startAtRight_dragLeft_activates() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 100))
    scrollView.contentOffset = .init(x: 200, y: 0)  // at right edge

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .left, diff: .init(x: -10, y: 0))

    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.right])
  }

  @Test("onlyAtGestureStart: horizontal — start at left edge activates .right")
  func onlyAtStart_horizontal_startAtLeft_dragRight_activates() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 100))
    scrollView.contentOffset = .zero  // at left edge

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .right, diff: .init(x: 10, y: 0))

    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.left])
  }

  @Test("onlyAtGestureStart: horizontal — mid-content .right drag does not activate even at left")
  func onlyAtStart_horizontal_midContent_dragRight_doesNotActivate() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 100))
    scrollView.contentOffset = .init(x: 50, y: 0)  // mid-content horizontally

    let handler = DragGestureHandler(configuration: Self.onlyAtStartConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    _ = runChanged(handler: handler, recognizer: recognizer, direction: .right, diff: .init(x: 10, y: 0))

    // Simulate reaching the left edge mid-gesture
    scrollView.contentOffset = .init(x: 0, y: 0)
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .right, diff: .init(x: 10, y: 0))

    #expect(changes.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
  }

  // MARK: - minimumActivationDistance

  private static let thresholdConfig = ScrollViewInteroperableDragGestureConfiguration(
    ignoresScrollView: false,
    targetEdges: .all,
    sticksToEdges: true,
    minimumActivationDistance: 10
  )

  @Test("minimumActivationDistance: below threshold, no onChange even at edge")
  func threshold_belowThreshold_doesNotActivate() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom

    let handler = DragGestureHandler(configuration: Self.thresholdConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // 4 + 4 = 8pt total — below 10pt threshold
    let changes1 = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -4))
    let changes2 = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -4))

    #expect(changes1.isEmpty)
    #expect(changes2.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
    #expect(handler.tracking.hasPassedActivationThreshold == false)
  }

  @Test("minimumActivationDistance: crossing threshold enables processing")
  func threshold_crossingThreshold_activates() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: Self.thresholdConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // 4pt — under
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -4))
    #expect(handler.tracking.hasPassedActivationThreshold == false)

    // accumulated 16pt — over 10pt
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -12))
    #expect(handler.tracking.hasPassedActivationThreshold == true)
    // The crossing-frame's diff is processed normally, so the outer onChange fires.
    #expect(changes.count == 1)
    #expect(handler.tracking.stickingEdges == [.bottom])
  }

  @Test("minimumActivationDistance: measured as magnitude from start, not path length")
  func threshold_jiggleDoesNotAccumulate() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: Self.thresholdConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Jiggle: +6 -6 +6 -6 = net 0, path length 24 — should NOT cross 10pt threshold
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -6))
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 6))
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -6))
    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 6))

    #expect(handler.tracking.hasPassedActivationThreshold == false)
    #expect(changes.isEmpty)
  }

  @Test("minimumActivationDistance: isScrollLockEnabled bypasses the gate")
  func threshold_isScrollLockEnabledBypasses() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)

    let handler = DragGestureHandler(configuration: Self.thresholdConfig)
    handler.isScrollLockEnabled = true
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -4))

    #expect(changes.count == 1)
    #expect(handler.tracking.translation == .init(width: 0, height: -4))
  }

  // MARK: - Scroll indicator hide/restore

  @Test("Scroll indicator is hidden on lock, restored on .ended")
  func indicator_hiddenOnLock_restoredOnEnded() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)
    scrollView.showsVerticalScrollIndicator = true

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(scrollView.showsVerticalScrollIndicator == false)

    // End gesture — indicator restored to initial value
    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    handler.handle(
      recognizer: recognizer,
      location: { .zero },
      velocity: { nil },
      onChange: { _ in },
      onEnd: { _ in }
    )

    #expect(scrollView.showsVerticalScrollIndicator == true)
  }

  @Test("Scroll indicator restored to initial false value")
  func indicator_initiallyHidden_stillRestoredAfterGesture() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)
    scrollView.showsVerticalScrollIndicator = false  // consumer-hidden

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(scrollView.showsVerticalScrollIndicator == false)

    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    handler.handle(
      recognizer: recognizer,
      location: { .zero },
      velocity: { nil },
      onChange: { _ in },
      onEnd: { _ in }
    )

    // Remains false (initial was false)
    #expect(scrollView.showsVerticalScrollIndicator == false)
  }

  @Test("Unlocking mid-gesture restores indicator immediately")
  func indicator_restoredOnUnlock() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom
    scrollView.showsVerticalScrollIndicator = true

    let handler = DragGestureHandler(configuration: .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: false
    ))
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Frame 1: activate (at bottom, drag up) — indicator hidden
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(scrollView.showsVerticalScrollIndicator == false)

    // Frame 2: reverse (drag down) — without sticky, unlocks, indicator restored
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 10))
    #expect(scrollView.showsVerticalScrollIndicator == true)
  }

  @Test("Horizontal indicator is managed independently of vertical")
  func indicator_horizontalVsVertical_independent() {
    let scrollView = makeScrollView(contentSize: .init(width: 300, height: 300))
    scrollView.contentOffset = .init(x: 200, y: 50)  // at right, mid-scroll vertically
    scrollView.showsVerticalScrollIndicator = true
    scrollView.showsHorizontalScrollIndicator = true

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Drag left (at right edge) — horizontal locks, vertical unaffected
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .left, diff: .init(x: -10, y: 0))
    #expect(scrollView.showsHorizontalScrollIndicator == false)
    #expect(scrollView.showsVerticalScrollIndicator == true)
  }

  // MARK: - External stickingEdges control

  @Test("overrideStickingEdges clears sticky state, reversal no longer continues")
  func external_clearStickingEdges_breaksReversal() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)  // at bottom

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Activate — .bottom sticks
    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(handler.tracking.stickingEdges == [.bottom])

    // Externally clear, then move scroll view off the edge so neither primary
    // nor sticky branch is satisfied in the next frame.
    handler.overrideStickingEdges([])
    scrollView.contentOffset = .init(x: 0, y: 50)

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .down, diff: .init(x: 0, y: 5))

    #expect(changes.isEmpty)
    #expect(handler.tracking.stickingEdges.isEmpty)
  }

  @Test("onStickingEdgesChange fires on insert and on gesture end")
  func external_onStickingEdgesChange_fires() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 200)

    let handler = DragGestureHandler(configuration: defaultConfig)
    var notifications: [ScrollViewEdge] = []
    handler.onStickingEdgesChange = { notifications.append($0) }
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    _ = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))
    #expect(notifications == [[.bottom]])

    // End — purge notifies with empty set
    recognizer.state = .ended
    recognizer.pan = ([], .zero)
    handler.handle(
      recognizer: recognizer,
      location: { .zero },
      velocity: { nil },
      onChange: { _ in },
      onEnd: { _ in }
    )

    #expect(notifications.count == 2)
    #expect(notifications.last == [])
  }

  @Test("overrideStickingEdges preset lets mid-content drag take over via sticky")
  func external_presetStickingEdges_activatesViaSticky() {
    let scrollView = makeScrollView(contentSize: .init(width: 100, height: 300))
    scrollView.contentOffset = .init(x: 0, y: 50)  // mid-content — would not activate normally

    let handler = DragGestureHandler(configuration: defaultConfig)
    let recognizer = MockRecognizer()
    recognizer.trackingScrollView = scrollView

    // Preset: pretend a previous downward drag already stuck at top (would
    // insert `.top`). Now on `.up`, the sticky OR checks `stickingEdges
    // .contains(.top)` and activates even though scroll view is mid-content.
    handler.overrideStickingEdges(.top)

    let changes = runChanged(handler: handler, recognizer: recognizer, direction: .up, diff: .init(x: 0, y: -10))

    #expect(changes.count == 1)
    // The sticky branch does not insert a new edge in this path (the
    // `.stickingEdges.insert(.bottom)` line runs, via setStickingEdges union).
    #expect(handler.tracking.stickingEdges == [.top, .bottom])
    #expect(handler.tracking.translation == .init(width: 0, height: -10))
  }
}
#endif
