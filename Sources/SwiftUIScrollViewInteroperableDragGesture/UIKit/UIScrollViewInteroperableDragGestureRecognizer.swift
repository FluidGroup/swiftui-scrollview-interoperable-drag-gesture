import UIKit

@MainActor
public final class UIScrollViewInteroperableDragGestureRecognizer: _ScrollViewDragGestureRecognizer {

  public typealias Value = ScrollViewInteroperableDragGestureValue
  public typealias Configuration = ScrollViewInteroperableDragGestureConfiguration

  public var configuration: Configuration {
    didSet {
      targetEdge = configuration.targetEdges
      handler.configuration = configuration
    }
  }

  public var isScrollLockEnabled: Bool {
    get { handler.isScrollLockEnabled }
    set { handler.isScrollLockEnabled = newValue }
  }

  /// Which edges the gesture is currently "sticking" to. Reactive to scroll view
  /// state during a drag; setting this forces the handler into (or out of) a
  /// sticky state. Writes only take effect while `configuration.sticksToEdges`
  /// is `true` — otherwise the handler ignores `stickingEdges` in its pan
  /// branches.
  public var stickingEdges: ScrollViewEdge {
    get { handler.tracking.stickingEdges }
    set { handler.overrideStickingEdges(newValue) }
  }

  public var onStickingEdgesChange: ((ScrollViewEdge) -> Void)?

  public weak var coordinateSpaceView: UIView?

  public var onChange: ((Value) -> Void)?
  public var onEnd: ((Value) -> Void)?

  private let handler: DragGestureHandler
  private let internalDelegate: InternalDelegate

  public init(
    configuration: Configuration = .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: true
    )
  ) {
    self.configuration = configuration
    self.handler = .init(configuration: configuration)
    self.internalDelegate = InternalDelegate(handler: handler)
    super.init(target: nil, action: nil)
    self.targetEdge = configuration.targetEdges
    self.delaysTouchesBegan = true
    self.delaysTouchesEnded = true
    self.delegate = internalDelegate
    self.addTarget(self, action: #selector(handleGesture))
    self.handler.onStickingEdgesChange = { [weak self] edges in
      self?.onStickingEdgesChange?(edges)
    }
  }

  @objc
  private func handleGesture() {
    let referenceView = coordinateSpaceView ?? view
    handler.handle(
      recognizer: self,
      location: { [weak self] in
        guard let self else { return .zero }
        return self.location(in: referenceView)
      },
      velocity: { [weak self] in
        guard let self else { return nil }
        return self.velocity(in: referenceView)
      },
      onChange: { [weak self] value in
        self?.onChange?(value)
      },
      onEnd: { [weak self] value in
        self?.onEnd?(value)
      }
    )
  }

  @MainActor
  private final class InternalDelegate: NSObject, UIGestureRecognizerDelegate {

    let handler: DragGestureHandler

    init(handler: DragGestureHandler) {
      self.handler = handler
    }

    func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      handler.shouldRecognizeSimultaneously(gestureRecognizer, with: otherGestureRecognizer)
    }
  }
}
