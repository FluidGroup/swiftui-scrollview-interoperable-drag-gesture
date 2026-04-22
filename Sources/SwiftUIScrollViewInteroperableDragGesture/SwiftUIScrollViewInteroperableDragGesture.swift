
import SwiftUI

@available(iOS 18, *)
public struct ScrollViewInteroperableDragGesture: UIGestureRecognizerRepresentable {

  public typealias Value = ScrollViewInteroperableDragGestureValue
  public typealias Configuration = ScrollViewInteroperableDragGestureConfiguration

  public final class Coordinator: NSObject, UIGestureRecognizerDelegate {

    let handler: DragGestureHandler

    init(configuration: Configuration) {
      self.handler = .init(configuration: configuration)
    }

    @objc
    public func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      handler.shouldRecognizeSimultaneously(gestureRecognizer, with: otherGestureRecognizer)
    }
  }

  private let coordinateSpaceInDragging: CoordinateSpaceProtocol
  private let _onChange: (Value) -> Void
  private let _onEnd: (Value) -> Void
  private let configuration: Configuration

  private let isScrollLockEnabled: Binding<Bool>

  public init(
    configuration: Configuration = .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: true
    ),
    isScrollLockEnabled: Binding<Bool> = .constant(false),
    coordinateSpaceInDragging: CoordinateSpaceProtocol,
    onChange: @escaping (Value) -> Void,
    onEnd: @escaping (Value) -> Void
  ) {
    self.configuration = configuration
    self.coordinateSpaceInDragging = coordinateSpaceInDragging
    self.isScrollLockEnabled = isScrollLockEnabled
    self._onChange = onChange
    self._onEnd = onEnd
  }

  public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
    return .init(configuration: configuration)
  }

  public func makeUIGestureRecognizer(context: Context) -> _ScrollViewDragGestureRecognizer {
    let gesture = _ScrollViewDragGestureRecognizer()
    gesture.targetEdge = configuration.targetEdges
    gesture.delaysTouchesBegan = true
    gesture.delaysTouchesEnded = true
    gesture.delegate = context.coordinator
    return gesture
  }

  public func handleUIGestureRecognizerAction(
    _ recognizer: _ScrollViewDragGestureRecognizer,
    context: Context
  ) {
    let handler = context.coordinator.handler
    handler.isScrollLockEnabled = isScrollLockEnabled.wrappedValue
    handler.configuration = configuration

    handler.handle(
      recognizer: recognizer,
      location: { context.converter.location(in: coordinateSpaceInDragging) },
      velocity: { context.converter.velocity(in: coordinateSpaceInDragging) },
      onChange: _onChange,
      onEnd: _onEnd
    )
  }
}

public class _ScrollViewDragGestureRecognizer: UIPanGestureRecognizer {

  struct PanDirection: OptionSet {
    let rawValue: Int

    static let up = PanDirection(rawValue: 1 << 0)
    static let down = PanDirection(rawValue: 1 << 1)
    static let left = PanDirection(rawValue: 1 << 2)
    static let right = PanDirection(rawValue: 1 << 3)

  }

  weak var trackingScrollView: UIScrollView?

  var targetEdge: ScrollViewEdge?

  func consumePan() -> (PanDirection, diff: CGPoint) {
    let translation = self.translation(in: view)

    self.setTranslation(.zero, in: view)

    let diff = translation

    var direction: PanDirection = []

    if diff.y > 0 {
      direction.insert(.down)
    } else if diff.y < 0 {
      direction.insert(.up)
    }

    if diff.x > 0 {
      direction.insert(.right)
    } else if diff.x < 0 {
      direction.insert(.left)
    }

    return (direction, diff)
  }

  public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    trackingScrollView = event.findScrollView(targetEdge: targetEdge!)
    super.touchesBegan(touches, with: event)
  }

  public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {

    super.touchesMoved(touches, with: event)
  }

  public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
  }

  public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)
  }

}

extension UIEvent {

  @MainActor
  fileprivate func findScrollView(targetEdge: ScrollViewEdge) -> UIScrollView? {

    guard
      let firstTouch = allTouches?.first,
      let targetView = firstTouch.view
    else { return nil }

    let scrollView = Array(sequence(first: targetView, next: { $0.next }))
      .last {
        guard let scrollView = $0 as? UIScrollView else {
          return false
        }

        @MainActor
        func isHorizontal(scrollView: UIScrollView) -> Bool {

          let contentInset = scrollView.adjustedContentInset

          return (scrollView.bounds.width - (contentInset.right + contentInset.left) < scrollView.contentSize.width)
        }

        @MainActor
        func isVertical(scrollView: UIScrollView) -> Bool {

          let contentInset = scrollView.adjustedContentInset

          return (scrollView.bounds.height - (contentInset.top + contentInset.bottom) < scrollView.contentSize.height)
        }

        var isTarget: Bool = false

        if isTarget == false && targetEdge.isSubset(of: .vertical) {
          isTarget = isVertical(scrollView: scrollView)
        }

        if isTarget == false && targetEdge.isSubset(of: .horizontal) {
          isTarget = isHorizontal(scrollView: scrollView)
        }

        return isTarget

      }

    return (scrollView as? UIScrollView)
  }

}
